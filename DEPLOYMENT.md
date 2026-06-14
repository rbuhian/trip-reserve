# Deployment Runbook (from scratch)

How to stand up the Trip Reserve backend on a fresh Supabase project: database, storage,
edge functions, secrets, scheduling, and the PayMongo webhook.

For feature-specific detail see:
- `PAYMENTS_SETUP.md` — PayMongo payments (keys, webhook, testing)
- `docs/firebase-setup.md` — Firebase / FCM (push notifications)

## 0. Prerequisites

- Supabase CLI installed, logged in, and linked: `supabase link --project-ref <ref>`
- Flutter SDK (for the app build)
- A Firebase project + service account JSON (push), a Gmail app password (email), and a
  PayMongo account (payments) — see the per-feature docs above.

> `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are **injected automatically** into every edge
> function — never set them yourself. The client app reads its own keys from `.env` (see `README.md`).

## 1. Database migrations

Apply all migrations in `supabase/migrations/` (includes storage buckets in `00006`):

```bash
supabase db push
```

Current migrations (applied in order):

| # | File | What |
|---|------|------|
| 00001 | core_tables | users, vehicles, bookings, payments, … |
| 00002 | supporting_tables | availability, pricing, addons, earnings |
| 00003 | rls_policies | Row Level Security for all tables |
| 00004 | indexes_triggers | indexes + triggers |
| 00005 | vehicle_details_documents | vehicle/driver document fields |
| 00006 | storage_buckets | Storage buckets (vehicle photos, docs) |
| 00007 | vehicle_categories | sedan / mpv_suv / van |
| 00008 | fix_handle_new_user_phone | auth trigger fix |
| 00009 | add_reminder_sent_at | trip-reminder dedup column |
| 00010 | device_tokens | FCM device tokens |
| 00011 | fix_earnings_trigger_security | earnings trigger hardening |
| 00012 | messaging | conversations + messages (+ Realtime) |
| 00013 | customer_read_driver | RLS: customer can read assigned driver |
| 00014 | payments_checkout | payments.checkout_session_id (+ Realtime) |
| 00015 | payouts | withdrawals + withdrawal_events, balance/withdrawal RPCs, earnings credit reconciliation (completed+paid), `payout-proofs` storage bucket, Realtime |

## 2. Secrets

Set all edge-function secrets in one go (omit any feature you're not enabling). Prefer
`--env-file` over inline args so keys don't land in shell history.

```bash
supabase secrets set \
  FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account", ... }' \
  SMTP_USERNAME=you@gmail.com \
  SMTP_PASSWORD=your-gmail-app-password \
  PAYMONGO_SECRET_KEY=sk_test_xxx \
  PAYMONGO_WEBHOOK_SECRET=whsk_xxx \
  PAYMENT_SUCCESS_URL=https://tripreserve.ph/payment/success \
  PAYMENT_CANCEL_URL=https://tripreserve.ph/payment/cancel
```

Verify with `supabase secrets list` (shows names + digests, not values).

## 3. Edge functions

| Function | Purpose | Invoked by | Secrets it needs | Deploy note |
|----------|---------|------------|------------------|-------------|
| `send-email` | Transactional emails (confirmation, receipt, …) | app | `SMTP_USERNAME`, `SMTP_PASSWORD` | default |
| `send-trip-reminders` | ~2h email **+ FCM** trip reminder | **cron** (every 30 min) | `SMTP_*`, `FIREBASE_SERVICE_ACCOUNT_JSON` | schedule it (§4) |
| `notify-driver-assigned` | FCM push when a driver accepts (prompts payment) | app | `FIREBASE_SERVICE_ACCOUNT_JSON` | default |
| `notify-booking-cancelled` | FCM push to the driver when a customer cancels | app | `FIREBASE_SERVICE_ACCOUNT_JSON` | default |
| `notify-trip-started` | FCM push when trip starts | app | `FIREBASE_SERVICE_ACCOUNT_JSON` | default |
| `notify-trip-completed` | FCM push when trip completes | app | `FIREBASE_SERVICE_ACCOUNT_JSON` | default |
| `notify-new-message` | FCM push for a new chat message | app | `FIREBASE_SERVICE_ACCOUNT_JSON` | default |
| `create-payment-checkout` | Create a PayMongo hosted checkout | app | `PAYMONGO_SECRET_KEY`, `PAYMENT_*` | default |
| `paymongo-webhook` | Receive PayMongo payment events | **PayMongo** | `PAYMONGO_WEBHOOK_SECRET` | **`--no-verify-jwt`** |

Deploy them:

```bash
supabase functions deploy send-email
supabase functions deploy send-trip-reminders
supabase functions deploy notify-driver-assigned
supabase functions deploy notify-booking-cancelled
supabase functions deploy notify-trip-started
supabase functions deploy notify-trip-completed
supabase functions deploy notify-new-message
supabase functions deploy create-payment-checkout
supabase functions deploy paymongo-webhook --no-verify-jwt
```

Notes:
- **`paymongo-webhook` must skip JWT verification** — PayMongo can't send a Supabase auth token;
  the function secures itself with the `PAYMONGO_WEBHOOK_SECRET` signature instead. Either deploy it
  with `--no-verify-jwt` (as above) or make it durable in `supabase/config.toml`:
  ```toml
  [functions.paymongo-webhook]
  verify_jwt = false
  ```
- The app-invoked functions keep JWT verification on (the Flutter client sends the user's token).
- `supabase functions deploy` with no name deploys **all** functions — fine, but you still need the
  `verify_jwt = false` config (above) for `paymongo-webhook` if you use the bulk form.

## 4. Schedule the trip reminders (cron)

`send-trip-reminders` must run on a schedule (it isn't app-invoked). Either:
- **Dashboard:** Edge Functions → `send-trip-reminders` → Schedule → `*/30 * * * *`, or
- **pg_cron + pg_net** (SQL editor) — see `supabase/functions/send-trip-reminders/README.md`.

## 5. Register the PayMongo webhook

After `paymongo-webhook` is deployed, register its URL in the PayMongo dashboard for
`checkout_session.payment.paid` + `payment.failed`, and put the signing secret in
`PAYMONGO_WEBHOOK_SECRET`. Full steps + test cards: `PAYMENTS_SETUP.md`.

URL: `https://<PROJECT-REF>.supabase.co/functions/v1/paymongo-webhook`

## 6. External setup (one-time, per feature)

- **Push:** add `android/app/google-services.json` (+ iOS `GoogleService-Info.plist`) and create the
  Firebase service account JSON used in `FIREBASE_SERVICE_ACCOUNT_JSON`. See `docs/firebase-setup.md`.
- **Email:** a Gmail account with an app password for `SMTP_USERNAME` / `SMTP_PASSWORD`.
- **Payments:** PayMongo `sk_test_` (then `sk_live_`) + the webhook. See `PAYMENTS_SETUP.md`.

## 7. App build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generated freezed/json files are gitignored
flutter run
```

## Quick checklist

- [ ] `supabase db push` (migrations + storage buckets)
- [ ] `supabase secrets set …` (Firebase / SMTP / PayMongo)
- [ ] Deploy all 9 functions (`paymongo-webhook` with `--no-verify-jwt`)
- [ ] Schedule `send-trip-reminders` (cron `*/30 * * * *`)
- [ ] Register the PayMongo webhook → copy `whsk_` into secrets
- [ ] `google-services.json` in place (push)
- [ ] App: `build_runner` + `flutter run`
