import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Environment ────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYMONGO_SECRET_KEY = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";
const PAYMENT_SUCCESS_URL =
  Deno.env.get("PAYMENT_SUCCESS_URL") ?? "https://tripreserve.ph/payment/success";
const PAYMENT_CANCEL_URL =
  Deno.env.get("PAYMENT_CANCEL_URL") ?? "https://tripreserve.ph/payment/cancel";

const PAYMONGO_BASE = "https://api.paymongo.com/v1";

// ─── Types ───────────────────────────────────────────────────────────────────

type Method = "gcash" | "card" | "paymaya";

interface CreateCheckoutRequest {
  bookingId: string;
  method: Method;
}

// Maps our payment method to PayMongo payment_method_types values.
const METHOD_MAP: Record<Method, string> = {
  gcash: "gcash",
  card: "card",
  paymaya: "paymaya",
};

// ─── CORS headers ────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// PayMongo auth: Basic base64("<secret_key>:") — empty password, trailing colon.
function paymongoAuthHeader(): string {
  return "Basic " + btoa(`${PAYMONGO_SECRET_KEY}:`);
}

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Validate credentials up front
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("Missing Supabase credentials");
    return jsonResponse({ error: "Supabase credentials not configured" }, 500);
  }

  if (!PAYMONGO_SECRET_KEY) {
    console.error("Missing PAYMONGO_SECRET_KEY");
    return jsonResponse({ error: "PayMongo secret key not configured" }, 500);
  }

  // Service-role client (amount is authoritative server-side).
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    // ── Step 1: Parse & validate body ────────────────────────────────────
    const { bookingId, method }: CreateCheckoutRequest = await req.json();

    if (!bookingId) {
      return jsonResponse({ error: "Missing required field: bookingId" }, 400);
    }

    if (!method || !(method in METHOD_MAP)) {
      return jsonResponse(
        { error: "Invalid method. Expected one of: gcash, card, paymaya" },
        400,
      );
    }
    const paymongoMethod = METHOD_MAP[method];

    // ── Step 2: Authorize the caller ─────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) {
      return jsonResponse({ error: "Missing Authorization bearer token" }, 401);
    }

    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData?.user) {
      console.error("Auth resolution failed:", userError);
      return jsonResponse({ error: "Invalid or expired authentication" }, 401);
    }
    const userId = userData.user.id;

    // ── Step 3: Fetch the booking (service role) ─────────────────────────
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id, customer_id, total_amount, reference_number, status")
      .eq("id", bookingId)
      .single();

    if (bookingError || !booking) {
      console.error("Booking not found:", bookingError);
      return jsonResponse({ error: "Booking not found" }, 404);
    }

    if (booking.customer_id !== userId) {
      console.warn(`User ${userId} does not own booking ${bookingId}`);
      return jsonResponse({ error: "You do not have access to this booking" }, 403);
    }

    // ── Step 4: Compute amount in centavos ───────────────────────────────
    const centavos = Math.round(Number(booking.total_amount) * 100);
    if (!Number.isFinite(centavos) || centavos <= 0) {
      return jsonResponse({ error: "Booking has an invalid payable amount" }, 400);
    }

    // ── Step 5: Insert a pending payment row ─────────────────────────────
    const { data: payment, error: insertError } = await supabase
      .from("payments")
      .insert({
        booking_id: booking.id,
        amount: booking.total_amount,
        method,
        status: "pending",
      })
      .select()
      .single();

    if (insertError || !payment) {
      console.error("Failed to insert payment row:", insertError);
      return jsonResponse({ error: "Failed to create payment record" }, 500);
    }
    const paymentId = payment.id;

    // ── Step 6: Create the PayMongo Checkout Session ─────────────────────
    const checkoutBody = {
      data: {
        attributes: {
          line_items: [
            {
              name: `Trip Reserve booking ${booking.reference_number}`,
              amount: centavos,
              currency: "PHP",
              quantity: 1,
            },
          ],
          payment_method_types: [paymongoMethod],
          description: `Trip Reserve ${booking.reference_number}`,
          reference_number: booking.reference_number,
          success_url: PAYMENT_SUCCESS_URL,
          cancel_url: PAYMENT_CANCEL_URL,
          metadata: {
            booking_id: String(bookingId),
            payment_id: String(paymentId),
          },
        },
      },
    };

    const pmResponse = await fetch(`${PAYMONGO_BASE}/checkout_sessions`, {
      method: "POST",
      headers: {
        Authorization: paymongoAuthHeader(),
        "Content-Type": "application/json",
      },
      body: JSON.stringify(checkoutBody),
    });

    const pmText = await pmResponse.text();

    if (!pmResponse.ok) {
      console.error(`PayMongo checkout session failed (${pmResponse.status})`);
      // Mark the payment row as failed with the PayMongo error body.
      await supabase
        .from("payments")
        .update({
          status: "failed",
          failure_reason: pmText.slice(0, 2000),
          failed_at: new Date().toISOString(),
        })
        .eq("id", paymentId);

      return jsonResponse(
        { error: "Failed to create PayMongo checkout session", details: pmText },
        502,
      );
    }

    const pmJson = JSON.parse(pmText);
    const checkoutUrl = pmJson?.data?.attributes?.checkout_url as string | undefined;
    const sessionId = pmJson?.data?.id as string | undefined;

    if (!checkoutUrl || !sessionId) {
      console.error("PayMongo response missing checkout_url or session id");
      await supabase
        .from("payments")
        .update({
          status: "failed",
          failure_reason: "PayMongo response missing checkout_url or session id",
          failed_at: new Date().toISOString(),
        })
        .eq("id", paymentId);

      return jsonResponse(
        { error: "Invalid PayMongo checkout session response" },
        502,
      );
    }

    // ── Step 7: Persist the session id on the payment row ────────────────
    const { error: updateError } = await supabase
      .from("payments")
      .update({
        checkout_session_id: sessionId,
        external_source_id: sessionId,
        status: "processing",
      })
      .eq("id", paymentId);

    if (updateError) {
      // The session exists at PayMongo; log but still return the URL so the
      // customer can pay. The webhook can reconcile by metadata/session id.
      console.error("Failed to update payment with session id:", updateError);
    }

    // ── Step 8: Return the checkout URL ──────────────────────────────────
    return jsonResponse({ checkoutUrl, paymentId }, 200);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("Unhandled error in create-payment-checkout:", msg);
    return jsonResponse({ error: "Unexpected error", details: msg }, 500);
  }
});
