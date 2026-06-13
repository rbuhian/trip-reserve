# send-trip-reminders Edge Function

Sends an email reminder **and** an FCM push notification to customers ~2 hours before their confirmed trip starts.

## Setup

Deploy the function:
```
supabase functions deploy send-trip-reminders
```

Set secrets (same as send-email):
```
supabase secrets set SMTP_USERNAME=your@gmail.com SMTP_PASSWORD=your-app-password
```

This function also needs the `FIREBASE_SERVICE_ACCOUNT_JSON` secret to send the FCM
push (the same value already set for `notify-trip-started` / `notify-driver-assigned`).
If the secret is absent, the function degrades gracefully to email-only — the email
reminder still goes out and bookings are still marked as reminded.
```
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

## Scheduling (Supabase Dashboard)

In the Supabase Dashboard → Edge Functions → send-trip-reminders → Schedule:
- Cron expression: `*/30 * * * *` (every 30 minutes)

Or via pg_cron (run in SQL editor after enabling the pg_net extension):
```sql
select cron.schedule(
  'send-trip-reminders',
  '*/30 * * * *',
  $$
  select net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/send-trip-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
```

## Manual Test
POST to the function URL with your service role Bearer token.
