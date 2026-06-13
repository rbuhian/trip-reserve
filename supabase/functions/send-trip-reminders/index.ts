import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

// ─── Environment ────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SMTP_USERNAME = Deno.env.get("SMTP_USERNAME") ?? "";
const SMTP_PASSWORD = Deno.env.get("SMTP_PASSWORD") ?? "";
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

// ─── Types ───────────────────────────────────────────────────────────────────

interface BookingRow {
  id: string;
  customer_id: string;
  reference_number: string;
  scheduled_date: string;   // ISO date string: "2026-06-10"
  pickup_time: string;      // VARCHAR like "14:30"
  pickup_address: string;
  dropoff_address: string;
  customer_email: string;
  customer_name: string;
  vehicle_name: string;
  plate_number: string;
}

interface ProcessResult {
  processed: number;
  pushed: number;
  errors: string[];
}

// ─── CORS headers ────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Combines a DATE string ("2026-06-10") and a pickup_time string ("14:30")
 * into a JavaScript Date object, interpreted as Philippine time (UTC+8).
 */
function buildTripDateTime(scheduledDate: string, pickupTime: string): Date {
  // "2026-06-10" + "14:30" → "2026-06-10T14:30:00+08:00"
  const [hours, minutes] = pickupTime.split(":").map(Number);
  const paddedHours = String(hours).padStart(2, "0");
  const paddedMinutes = String(minutes ?? 0).padStart(2, "0");
  const isoString = `${scheduledDate}T${paddedHours}:${paddedMinutes}:00+08:00`;
  return new Date(isoString);
}

/**
 * Formats a date string for display in the email (e.g. "Tuesday, June 10, 2026").
 */
function formatDisplayDate(scheduledDate: string): string {
  const date = new Date(`${scheduledDate}T00:00:00+08:00`);
  return date.toLocaleDateString("en-PH", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "Asia/Manila",
  });
}

/**
 * Formats a pickup_time string for display (e.g. "2:30 PM").
 */
function formatDisplayTime(pickupTime: string): string {
  const [hours, minutes] = pickupTime.split(":").map(Number);
  const ampm = hours >= 12 ? "PM" : "AM";
  const displayHour = hours % 12 === 0 ? 12 : hours % 12;
  const displayMinutes = String(minutes ?? 0).padStart(2, "0");
  return `${displayHour}:${displayMinutes} ${ampm}`;
}

// ─── Email template ───────────────────────────────────────────────────────────

function buildReminderEmailHtml(booking: BookingRow): string {
  const displayDate = formatDisplayDate(booking.scheduled_date);
  const displayTime = formatDisplayTime(booking.pickup_time);

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Trip Reminder</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background-color: #0C2340; padding: 30px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Trip Reserve</h1>
              <p style="color: #a0b4c8; margin: 8px 0 0 0; font-size: 15px;">Trip Reminder</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding: 30px;">
              <h2 style="color: #0C2340; margin: 0 0 16px 0; font-size: 22px;">Your trip is coming up in about 2 hours!</h2>

              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 24px 0;">
                Hi ${booking.customer_name},<br><br>
                This is a friendly reminder that your upcoming trip with Trip Reserve is starting soon. Please make sure you're ready at the pickup location on time.
              </p>

              <!-- Reference Number -->
              <div style="background-color: #f0f4f8; border-radius: 8px; padding: 16px; margin-bottom: 24px; text-align: center;">
                <p style="color: #666666; font-size: 13px; margin: 0 0 4px 0; text-transform: uppercase; letter-spacing: 1px;">Booking Reference</p>
                <p style="color: #0C2340; font-size: 24px; font-weight: bold; margin: 0; letter-spacing: 2px;">${booking.reference_number}</p>
              </div>

              <!-- Trip Details Card -->
              <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; margin-bottom: 24px;">
                <h3 style="color: #0C2340; margin: 0 0 16px 0; font-size: 17px;">Trip Details</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px; width: 40%;">Date</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: 500;">${displayDate}</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Pickup Time</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: 500;">${displayTime}</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Vehicle</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: 500;">${booking.vehicle_name}</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Plate Number</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: 500; font-family: monospace; letter-spacing: 1px;">${booking.plate_number}</td>
                  </tr>
                </table>

                <!-- Pickup / Dropoff -->
                <div style="margin-top: 16px;">
                  <div style="background-color: #e8f5e9; border-radius: 6px; padding: 12px; margin-bottom: 8px;">
                    <p style="color: #2e7d32; font-size: 11px; margin: 0 0 4px 0; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;">Pickup</p>
                    <p style="color: #333333; font-size: 14px; margin: 0; line-height: 1.4;">${booking.pickup_address}</p>
                  </div>
                  <div style="background-color: #fce4ec; border-radius: 6px; padding: 12px;">
                    <p style="color: #b71c1c; font-size: 11px; margin: 0 0 4px 0; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;">Drop-off</p>
                    <p style="color: #333333; font-size: 14px; margin: 0; line-height: 1.4;">${booking.dropoff_address}</p>
                  </div>
                </div>
              </div>

              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 8px 0;">
                Have a great trip! If you need to make any changes, please contact support as soon as possible.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #666666; font-size: 14px; margin: 0 0 8px 0;">
                Questions? Contact us at support@tripreserve.ph
              </p>
              <p style="color: #999999; font-size: 12px; margin: 0;">
                &copy; 2024 Trip Reserve. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
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
    return new Response(
      JSON.stringify({ error: "Supabase credentials not configured" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (!SMTP_USERNAME || !SMTP_PASSWORD) {
    console.error("Missing SMTP credentials");
    return new Response(
      JSON.stringify({ error: "SMTP credentials not configured" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // FCM push is best-effort. Email remains required; push is enabled only when
  // the Firebase service account secret is present.
  let pushEnabled = FIREBASE_SERVICE_ACCOUNT_JSON.length > 0;
  if (!pushEnabled) {
    console.warn("FIREBASE_SERVICE_ACCOUNT_JSON not set — FCM push disabled, sending email only");
  }

  const result: ProcessResult = { processed: 0, pushed: 0, errors: [] };

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Step 1: Fetch candidate bookings ──────────────────────────────────
    // We fetch confirmed bookings with no reminder sent where scheduled_date
    // is today or tomorrow (Asia/Manila), then filter the exact 1.5–3 h
    // window in Deno to avoid complex SQL on the JS client.

    const now = new Date();
    // Get today's and tomorrow's dates in Manila time (UTC+8)
    const manilaOffsetMs = 8 * 60 * 60 * 1000;
    const manilaMs = now.getTime() + manilaOffsetMs;
    const manilaDate = new Date(manilaMs);
    const todayStr = manilaDate.toISOString().slice(0, 10);   // "YYYY-MM-DD"
    const tomorrow = new Date(manilaMs + 24 * 60 * 60 * 1000);
    const tomorrowStr = tomorrow.toISOString().slice(0, 10);

    const { data: bookings, error: fetchError } = await supabase
      .from("bookings")
      .select(`
        id,
        customer_id,
        reference_number,
        scheduled_date,
        pickup_time,
        pickup_address,
        dropoff_address,
        reminder_sent_at,
        customer:customer_id (
          email,
          full_name
        ),
        vehicle:vehicle_id (
          name,
          plate_number
        )
      `)
      .eq("status", "confirmed")
      .is("reminder_sent_at", null)
      .in("scheduled_date", [todayStr, tomorrowStr]);

    if (fetchError) {
      console.error("Error fetching bookings:", fetchError);
      return new Response(
        JSON.stringify({ error: `Database query failed: ${fetchError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!bookings || bookings.length === 0) {
      console.log("No candidate bookings found");
      return new Response(
        JSON.stringify(result),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Candidate bookings fetched: ${bookings.length}`);

    // ── Step 2: Filter to the 1.5–3 h window ─────────────────────────────

    const windowStart = new Date(now.getTime() + 1.5 * 60 * 60 * 1000); // NOW + 1.5 h
    const windowEnd   = new Date(now.getTime() + 3.0 * 60 * 60 * 1000); // NOW + 3.0 h

    // Flatten the Supabase join shape into BookingRow[]
    // deno-lint-ignore no-explicit-any
    const candidates: BookingRow[] = (bookings as any[])
      .filter((b) => {
        const tripTime = buildTripDateTime(b.scheduled_date, b.pickup_time);
        return tripTime >= windowStart && tripTime <= windowEnd;
      })
      .map((b) => ({
        id: b.id,
        customer_id: b.customer_id,
        reference_number: b.reference_number,
        scheduled_date: b.scheduled_date,
        pickup_time: b.pickup_time,
        pickup_address: b.pickup_address,
        dropoff_address: b.dropoff_address,
        customer_email: b.customer?.email ?? "",
        customer_name: b.customer?.full_name ?? "Valued Customer",
        vehicle_name: b.vehicle?.name ?? "Your Vehicle",
        plate_number: b.vehicle?.plate_number ?? "—",
      }));

    console.log(`Bookings in reminder window: ${candidates.length}`);

    if (candidates.length === 0) {
      return new Response(
        JSON.stringify(result),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Step 3: Acquire FCM OAuth token once (best-effort) ────────────────

    let accessToken: string | null | undefined;
    let projectId = "";
    if (pushEnabled) {
      try {
        const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON.trim().replace(/^'+|'+$/g, ""));
        const auth = new GoogleAuth({
          credentials: serviceAccount,
          scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
        });
        accessToken = await auth.getAccessToken();
        projectId = serviceAccount.project_id;
      } catch (e) {
        console.error("FCM auth failed, push disabled:", e);
        pushEnabled = false;
      }
    }

    // ── Step 4: Send emails (and best-effort push) one at a time ──────────

    for (const booking of candidates) {
      try {
        console.log(`Processing booking ${booking.reference_number} for ${booking.customer_email}`);

        if (!booking.customer_email) {
          const msg = `Booking ${booking.reference_number}: missing customer email, skipping`;
          console.warn(msg);
          result.errors.push(msg);
          continue;
        }

        const subject = `Reminder: Your Trip Reserve booking is in 2 hours – Ref #${booking.reference_number}`;
        const html = buildReminderEmailHtml(booking);

        // Send via Gmail SMTP (new client per booking to avoid connection reuse issues)
        const client = new SMTPClient({
          connection: {
            hostname: "smtp.gmail.com",
            port: 465,
            tls: true,
            auth: { username: SMTP_USERNAME, password: SMTP_PASSWORD },
          },
        });

        await client.send({
          from: `Trip Reserve <${SMTP_USERNAME}>`,
          to: booking.customer_email,
          subject,
          html,
        });

        await client.close();

        console.log(`Email sent to ${booking.customer_email} for booking ${booking.reference_number}`);

        // Best-effort FCM push. A push failure must NEVER block marking the
        // booking as reminded — the required email has already been sent.
        if (pushEnabled) {
          try {
            const { data: deviceTokens, error: tokensError } = await supabase
              .from("device_tokens")
              .select("token")
              .eq("user_id", booking.customer_id);

            if (tokensError) {
              console.error(`Booking ${booking.reference_number}: error fetching device tokens:`, tokensError);
            }

            if (!deviceTokens || deviceTokens.length === 0) {
              console.log(`Booking ${booking.reference_number}: no device tokens for customer ${booking.customer_id}, skipping push`);
            } else {
              const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
              const pushResults = await Promise.allSettled(
                deviceTokens.map(({ token }) =>
                  fetch(fcmUrl, {
                    method: "POST",
                    headers: {
                      "Authorization": `Bearer ${accessToken}`,
                      "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                      message: {
                        token,
                        notification: {
                          title: "Trip Reminder",
                          body: "Your trip is starting in about 2 hours. Please be ready at your pickup location.",
                        },
                        data: {
                          type: "trip_reminder",
                          booking_id: booking.id,
                        },
                      },
                    }),
                  }).then(async (res) => {
                    if (!res.ok) {
                      const errorBody = await res.text();
                      throw new Error(`FCM error ${res.status}: ${errorBody}`);
                    }
                    return res.json();
                  })
                )
              );

              for (const pushResult of pushResults) {
                if (pushResult.status === "fulfilled") {
                  result.pushed++;
                } else {
                  const message = pushResult.reason instanceof Error
                    ? pushResult.reason.message
                    : String(pushResult.reason);
                  const msg = `Booking ${booking.reference_number}: FCM push failure – ${message}`;
                  console.error(msg);
                  result.errors.push(msg);
                }
              }
            }
          } catch (pushError) {
            const msg = `Booking ${booking.reference_number}: push step failed – ${
              pushError instanceof Error ? pushError.message : String(pushError)
            }`;
            console.error(msg);
            result.errors.push(msg);
          }
        }

        // Mark reminder as sent
        const { error: updateError } = await supabase
          .from("bookings")
          .update({ reminder_sent_at: new Date().toISOString() })
          .eq("id", booking.id);

        if (updateError) {
          // Email was sent but we failed to mark it — log but don't count as a full error
          const msg = `Booking ${booking.reference_number}: email sent but failed to update reminder_sent_at: ${updateError.message}`;
          console.error(msg);
          result.errors.push(msg);
        }

        result.processed++;
      } catch (emailError) {
        const msg = `Booking ${booking.reference_number}: failed to send email – ${
          emailError instanceof Error ? emailError.message : String(emailError)
        }`;
        console.error(msg);
        result.errors.push(msg);
      }
    }
  } catch (err) {
    const msg = `Unexpected error: ${err instanceof Error ? err.message : String(err)}`;
    console.error(msg);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  console.log(`Done. Processed: ${result.processed}, Pushed: ${result.pushed}, Errors: ${result.errors.length}`);
  return new Response(
    JSON.stringify(result),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
