# notify-new-message Edge Function

Sends an FCM push notification to the recipient participant of a conversation when a
new in-app message is sent (MSG-08). The recipient is the conversation participant who
is **not** the message sender.

## Contract

```
POST { "messageId": "<uuid>" }
```

Responses:
- `200 { "success": true, "sent": <n>, "errors": [...] }` — notifications attempted (best-effort).
- `200 { "success": true, "sent": 0 }` — recipient has no device tokens.
- `200 { "success": true, "sent": 0, "skipped": "firebase_not_configured" }` — `FIREBASE_SERVICE_ACCOUNT_JSON` not set; degrades gracefully.
- `400` — missing `messageId`.
- `404` — message or conversation not found.
- `500` — unhandled error.

The push payload is `notification.title` = sender's `full_name` (fallback "New message"),
`notification.body` = the message body truncated to ~120 chars, and
`data` = `{ type: "new_message", booking_id, conversation_id }`.

## Setup

Deploy the function:
```
supabase functions deploy notify-new-message
```

This function needs the `FIREBASE_SERVICE_ACCOUNT_JSON` secret (the same value already
set for `notify-trip-started` / `notify-driver-assigned` / `notify-trip-completed`).
If the secret is absent, the function degrades gracefully and returns `sent: 0`.
```
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

It uses `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` (injected automatically in the
Supabase runtime) for the service-role client.

## Manual Test
POST to the function URL with your service role Bearer token and a valid `messageId`.
```
curl -X POST "$SUPABASE_URL/functions/v1/notify-new-message" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"messageId":"<uuid>"}'
```
