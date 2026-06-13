import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NotifyNewMessageRequest {
  messageId: string;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { messageId }: NotifyNewMessageRequest = await req.json();

    if (!messageId) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required field: messageId" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Step 1: Look up the message
    const { data: message, error: messageError } = await supabase
      .from("messages")
      .select("id, conversation_id, sender_id, body")
      .eq("id", messageId)
      .single();

    if (messageError || !message) {
      console.error("Message not found:", messageError);
      return new Response(
        JSON.stringify({ success: false, error: "Message not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 2: Look up the conversation (participants + booking)
    const { data: conversation, error: conversationError } = await supabase
      .from("conversations")
      .select("id, customer_id, driver_id, booking_id")
      .eq("id", message.conversation_id)
      .single();

    if (conversationError || !conversation) {
      console.error("Conversation not found:", conversationError);
      return new Response(
        JSON.stringify({ success: false, error: "Conversation not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 3: Recipient is the participant who is NOT the sender
    const recipientId =
      message.sender_id === conversation.customer_id
        ? conversation.driver_id
        : conversation.customer_id;

    // Step 4: Look up the sender's display name (for the notification title)
    const { data: sender } = await supabase
      .from("users")
      .select("full_name")
      .eq("id", message.sender_id)
      .single();

    const senderName = sender?.full_name ?? "New message";

    // Step 5: Fetch the recipient's device tokens
    const { data: deviceTokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", recipientId);

    if (tokensError) {
      console.error("Error fetching device tokens:", tokensError);
    }

    if (!deviceTokens || deviceTokens.length === 0) {
      console.log("No device tokens found for recipient:", recipientId);
      return new Response(
        JSON.stringify({ success: true, sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Firebase service account is required to send the push. Degrade gracefully if absent.
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      console.error("FIREBASE_SERVICE_ACCOUNT_JSON is not configured");
      return new Response(
        JSON.stringify({ success: true, sent: 0, skipped: "firebase_not_configured" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Step 6: Get FCM OAuth access token
    const serviceAccount = JSON.parse(serviceAccountJson.trim().replace(/^'+|'+$/g, ""));
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const accessToken = await auth.getAccessToken();
    const projectId = serviceAccount.project_id;

    // Build notification content
    const notificationTitle = senderName;
    const notificationBody =
      message.body.length > 120 ? `${message.body.slice(0, 117)}...` : message.body;

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    // Send FCM notification to each token
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
                type: "new_message",
                booking_id: conversation.booking_id,
                conversation_id: conversation.id,
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
    console.error("Unhandled error in notify-new-message:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
