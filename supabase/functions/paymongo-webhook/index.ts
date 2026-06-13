import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Environment ────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYMONGO_WEBHOOK_SECRET = Deno.env.get("PAYMONGO_WEBHOOK_SECRET") ?? "";

// ─── CORS headers ────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, paymongo-signature",
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Constant-time comparison of two hex strings to avoid timing attacks.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

/**
 * Computes HMAC-SHA256(key, msg) and returns the lowercase hex digest.
 */
async function hmacSha256Hex(key: string, msg: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(msg));
  return Array.from(new Uint8Array(sigBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Parses the Paymongo-Signature header.
 * Format: "t=<timestamp>,te=<sig>,li=<sig>"
 *   - t  = timestamp used in the signed payload
 *   - te = signature for test-mode webhooks
 *   - li = signature for live-mode webhooks
 */
function parseSignatureHeader(
  header: string,
): { t?: string; te?: string; li?: string } {
  const parts: Record<string, string> = {};
  for (const segment of header.split(",")) {
    const idx = segment.indexOf("=");
    if (idx === -1) continue;
    const k = segment.slice(0, idx).trim();
    const v = segment.slice(idx + 1).trim();
    parts[k] = v;
  }
  return { t: parts["t"], te: parts["te"], li: parts["li"] };
}

/**
 * Verifies the PayMongo webhook signature.
 * Returns true if valid OR if verification is skipped (no secret configured).
 */
async function verifySignature(
  signatureHeader: string | null,
  rawBody: string,
): Promise<boolean> {
  if (!PAYMONGO_WEBHOOK_SECRET) {
    console.warn(
      "PAYMONGO_WEBHOOK_SECRET not set — skipping signature verification (local/testing mode)",
    );
    return true;
  }

  if (!signatureHeader) {
    console.error("Missing Paymongo-Signature header");
    return false;
  }

  const { t, te, li } = parseSignatureHeader(signatureHeader);
  if (!t || (!te && !li)) {
    console.error("Malformed Paymongo-Signature header");
    return false;
  }

  const expected = await hmacSha256Hex(PAYMONGO_WEBHOOK_SECRET, `${t}.${rawBody}`);

  // A signature is valid if it matches either the test-mode or live-mode value.
  const candidates = [te, li].filter((s): s is string => !!s);
  return candidates.some((sig) => timingSafeEqual(expected, sig));
}

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("Missing Supabase credentials");
    return jsonResponse({ error: "Supabase credentials not configured" }, 500);
  }

  // ── Step 1: Read the raw body (needed for signature verification) ──────
  const rawBody = await req.text();

  // ── Step 2: Verify signature ──────────────────────────────────────────
  const signatureHeader = req.headers.get("Paymongo-Signature");
  const valid = await verifySignature(signatureHeader, rawBody);
  if (!valid) {
    console.error("PayMongo webhook signature verification failed");
    return jsonResponse({ error: "Invalid signature" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    // ── Step 3: Parse the event ─────────────────────────────────────────
    // deno-lint-ignore no-explicit-any
    const payload: any = JSON.parse(rawBody);
    const eventType: string | undefined = payload?.data?.attributes?.type;
    // The underlying resource (a payment or checkout_session object).
    const resource = payload?.data?.attributes?.data;

    if (!eventType || !resource) {
      console.warn("Webhook payload missing event type or resource — ignoring");
      return jsonResponse({ received: true }, 200);
    }

    console.log(`PayMongo webhook event: ${eventType}, resource id: ${resource?.id}`);

    const resourceAttrs = resource?.attributes ?? {};
    // metadata can live on the resource, or — for checkout_session events — on
    // the nested payment(s). Prefer the resource-level metadata first.
    const metadata = resourceAttrs?.metadata ?? {};
    const metadataPaymentId: string | undefined = metadata?.payment_id;

    const isPaid = eventType.endsWith(".paid");
    const isFailed = eventType.endsWith(".failed");

    if (!isPaid && !isFailed) {
      console.log(`Ignoring unhandled event type: ${eventType}`);
      return jsonResponse({ received: true }, 200);
    }

    // ── Step 4: Locate our payment row ──────────────────────────────────
    // Resolution order:
    //   1. metadata.payment_id (most reliable — set at checkout creation)
    //   2. checkout_session_id == resource.id (for checkout_session.* events)
    //   3. external_id == resource.id (for payment.* events seen before)
    let query = supabase.from("payments").select("id, status").limit(1);

    if (metadataPaymentId) {
      query = query.eq("id", metadataPaymentId);
    } else if (resource?.id) {
      // resource.id is a cs_... for checkout_session events, or pay_... otherwise.
      query = query.or(
        `checkout_session_id.eq.${resource.id},external_id.eq.${resource.id}`,
      );
    } else {
      console.warn("No metadata.payment_id and no resource id — cannot match payment");
      return jsonResponse({ received: true }, 200);
    }

    const { data: paymentRow, error: lookupError } = await query.maybeSingle();

    if (lookupError) {
      console.error("Error looking up payment row:", lookupError);
      // Return 200 so PayMongo does not hammer us; we logged the failure.
      return jsonResponse({ received: true }, 200);
    }

    if (!paymentRow) {
      console.warn(
        `No matching payment row for event ${eventType} (metadata payment_id=${metadataPaymentId}, resource id=${resource?.id})`,
      );
      return jsonResponse({ received: true }, 200);
    }

    // ── Step 5: Resolve the PayMongo payment id (for external_id) ────────
    // For checkout_session.payment.paid, the actual payment id is nested under
    // attributes.payments[].id; for payment.* events it is the resource id.
    let paymongoPaymentId: string | undefined = resource?.id;
    const nestedPayments = resourceAttrs?.payments;
    if (Array.isArray(nestedPayments) && nestedPayments.length > 0) {
      paymongoPaymentId = nestedPayments[nestedPayments.length - 1]?.id ?? paymongoPaymentId;
    }

    // ── Step 6: Apply the status update ─────────────────────────────────
    if (isPaid) {
      const { error: updateError } = await supabase
        .from("payments")
        .update({
          status: "paid",
          paid_at: new Date().toISOString(),
          external_id: paymongoPaymentId,
        })
        .eq("id", paymentRow.id);

      if (updateError) {
        console.error("Failed to mark payment paid:", updateError);
      } else {
        console.log(`Payment ${paymentRow.id} marked as paid`);
      }
    } else if (isFailed) {
      const failureReason =
        resourceAttrs?.failed_message ??
        resourceAttrs?.last_payment_error?.message ??
        `PayMongo event ${eventType}`;

      const { error: updateError } = await supabase
        .from("payments")
        .update({
          status: "failed",
          failed_at: new Date().toISOString(),
          failure_reason: String(failureReason).slice(0, 2000),
        })
        .eq("id", paymentRow.id);

      if (updateError) {
        console.error("Failed to mark payment failed:", updateError);
      } else {
        console.log(`Payment ${paymentRow.id} marked as failed`);
      }
    }

    return jsonResponse({ received: true }, 200);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("Unhandled error in paymongo-webhook:", msg);
    // Still return 200 to avoid PayMongo retry storms; the error is logged.
    return jsonResponse({ received: true }, 200);
  }
});
