import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NotifyTripCompletedRequest {
  bookingId: string;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      console.error("FIREBASE_SERVICE_ACCOUNT_JSON is not configured");
      return new Response(
        JSON.stringify({ success: false, error: "Firebase service account not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { bookingId }: NotifyTripCompletedRequest = await req.json();

    if (!bookingId) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required field: bookingId" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Step 1: Query the booking with driver info
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select(`
        id,
        customer_id,
        driver:users!driver_id(full_name)
      `)
      .eq("id", bookingId)
      .single();

    if (bookingError || !booking) {
      console.error("Booking not found:", bookingError);
      return new Response(
        JSON.stringify({ success: false, error: "Booking not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 2: Query customer's device tokens
    const { data: deviceTokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", booking.customer_id);

    if (tokensError) {
      console.error("Error fetching device tokens:", tokensError);
    }

    if (!deviceTokens || deviceTokens.length === 0) {
      console.log("No device tokens found for customer:", booking.customer_id);
      return new Response(
        JSON.stringify({ success: true, sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 3: Get FCM OAuth access token
    const serviceAccount = JSON.parse(serviceAccountJson.trim().replace(/^'+|'+$/g, ""));
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const accessToken = await auth.getAccessToken();
    const projectId = serviceAccount.project_id;

    // Step 4: Build notification content
    const driverName = (booking.driver as { full_name: string } | null)?.full_name ?? "your driver";

    const notificationTitle = "Trip Completed";
    const notificationBody = `Thanks for riding with us! Your trip with ${driverName} is complete.`;

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    // Step 5: Send FCM notification to each token
    const results = await Promise.allSettled(
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
                title: notificationTitle,
                body: notificationBody,
              },
              data: {
                type: "trip_completed",
                booking_id: bookingId,
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

    let sent = 0;
    const errors: string[] = [];

    for (const result of results) {
      if (result.status === "fulfilled") {
        sent++;
      } else {
        const message = result.reason instanceof Error ? result.reason.message : String(result.reason);
        console.error("FCM send failure:", message);
        errors.push(message);
      }
    }

    console.log(`FCM notifications sent: ${sent}/${deviceTokens.length}`);

    return new Response(
      JSON.stringify({ success: true, sent, errors }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Unhandled error in notify-trip-completed:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
