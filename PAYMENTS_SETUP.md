# Payments Setup (PayMongo)

Setup guide for the PayMongo hosted-checkout payment flow (INF-05, CUST-22, CUST-23).

Customers pay for a booking **after a driver accepts it** via PayMongo's hosted checkout page
(GCash / Card / Maya). No card data touches the app — PayMongo hosts the payment form. A webhook
is the source of truth that marks a payment `paid`, and the app reacts in real time.

## Architecture

```
Confirm Booking → booking created (pending) → success screen   (no payment yet)
  → driver accepts → booking becomes 'confirmed'
  → customer opens Booking Details → "Pay now ₱X" appears (shown once confirmed)
  → /book/payment/:bookingId  (pick GCash / Card / Maya → Pay)
  → edge fn create-payment-checkout
       (server reads booking.total_amount, creates a payments row +
        PayMongo Checkout Session, returns checkout_url)
  → app opens checkout_url in the browser (url_launcher)
  → customer pays on PayMongo's hosted page
  → edge fn paymongo-webhook  (checkout_session.payment.paid → mark payment paid)
  → app sees the paid row via Supabase Realtime → Booking Details shows "Paid"
```

Components:
- DB: `payments` table (+ `checkout_session_id`, migration `00014`), Realtime enabled.
- Edge functions: `create-payment-checkout`, `paymongo-webhook`.
- App: `PaymentMethodScreen`, `payment_repository.dart`, `paymentForBookingProvider`.

## Prerequisites

- A PayMongo merchant account — https://dashboard.paymongo.com
- Supabase CLI installed and linked to the project (`supabase link`)
- The Supabase project ref (Supabase dashboard → Project Settings → General)

## Where to get the PayMongo keys

### `PAYMONGO_SECRET_KEY` (`sk_test_...` / `sk_live_...`)
1. PayMongo dashboard → **Developers → API Keys**.
2. Toggle **Test mode** (start here — test keys are available immediately).
3. Copy the **Secret key** (`sk_test_...`). The Public key (`pk_...`) is NOT needed.
4. Live keys (`sk_live_...`) only appear after PayMongo approves your business (KYC). Build and
   test with `sk_test_` first.

### `PAYMONGO_WEBHOOK_SECRET` (`whsk_...`)
This does not exist until you create the webhook, and the webhook needs the deployed function URL
— so deploy the function first (below), then create the webhook, then copy its signing secret.

- Webhook URL (after deploying `paymongo-webhook`):
  ```
  https://<YOUR-PROJECT-REF>.supabase.co/functions/v1/paymongo-webhook
  ```
- PayMongo dashboard → **Developers → Webhooks → Add Endpoint**:
  - **URL:** the function URL above
  - **Events:** `checkout_session.payment.paid` and `payment.failed` (also `payment.paid` if listed)
  - Save → copy the **Signing secret** (`whsk_...`).

If your account only exposes webhooks via API, create it with curl — the response's
`attributes.secret_key` is the `whsk_...`:
```bash
curl https://api.paymongo.com/v1/webhooks \
  -u sk_test_xxx: \
  -H "Content-Type: application/json" \
  -d '{"data":{"attributes":{
      "url":"https://<PROJECT-REF>.supabase.co/functions/v1/paymongo-webhook",
      "events":["checkout_session.payment.paid","payment.failed"]}}}'
```

## Deploy steps

Run from the repo root.

```bash
# 1. Apply the migration (adds checkout_session_id + enables Realtime on payments)
supabase db push

# 2. Deploy the edge functions
supabase functions deploy create-payment-checkout
supabase functions deploy paymongo-webhook --no-verify-jwt   # PayMongo cannot send a Supabase JWT

# 3. Create the webhook in PayMongo (see above) and copy the whsk_... signing secret

# 4. Set the secrets (one command, multiple KEY=value pairs)
supabase secrets set \
  PAYMONGO_SECRET_KEY=sk_test_xxx \
  PAYMONGO_WEBHOOK_SECRET=whsk_xxx \
  PAYMENT_SUCCESS_URL=https://tripreserve.ph/payment/success \
  PAYMENT_CANCEL_URL=https://tripreserve.ph/payment/cancel
```

Notes:
- `--no-verify-jwt` on the webhook is **required** — otherwise Supabase rejects PayMongo's calls
  (they can't present a Supabase auth token). The function secures itself with the `whsk_` signature.
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected into edge functions automatically —
  do NOT set them yourself.
- `PAYMENT_SUCCESS_URL` / `PAYMENT_CANCEL_URL` are optional (defaults:
  `https://tripreserve.ph/payment/success` and `.../cancel`).
- `secrets set` upserts — you can re-run it to update individual keys. Verify with
  `supabase secrets list` (shows names + digests, not values).
- The webhook function **degrades gracefully**: until `PAYMONGO_WEBHOOK_SECRET` is set it logs a
  warning and skips signature verification, so it won't hard-fail before the secret exists.

## Required Supabase secrets

| Secret | Example | Required | Notes |
|--------|---------|----------|-------|
| `PAYMONGO_SECRET_KEY` | `sk_test_...` | Yes | API Keys page |
| `PAYMONGO_WEBHOOK_SECRET` | `whsk_...` | Strongly recommended | From the webhook you create |
| `PAYMENT_SUCCESS_URL` | `https://.../success` | No | Redirect after success |
| `PAYMENT_CANCEL_URL` | `https://.../cancel` | No | Redirect after cancel |

## App build note

The generated freezed/json files (`lib/models/payment.freezed.dart`, `payment.g.dart`) are
gitignored. On a fresh checkout, regenerate them:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Testing (test mode)

1. Use `sk_test_` + a test-mode webhook.
2. In the app: create a booking, then have a driver **accept** it (so it becomes `confirmed`).
3. As the customer, open the booking's **Details** → tap **Pay now ₱X** → pick a method → Pay → the
   hosted page opens.
4. Pay with PayMongo's test instruments (e.g. test card `4343 4343 4343 4345`, any future expiry/CVC;
   GCash/Maya test flows have a "success/fail" choice on the sandbox page). See PayMongo's testing docs.
5. On success, the webhook flips the `payments` row to `paid`; the app returns to Booking Details,
   which now shows **Paid** (via Realtime). Verify the row in Supabase → Table Editor → `payments`.

### Test cards & instruments

Official docs: https://developers.paymongo.com/docs/testing (the "Test Cards" / payment-methods
testing section). Verify against the live page — PayMongo can change these.

Test instruments only work with **test-mode keys** (`sk_test_...`). Real cards are rejected in test
mode, and these test cards are rejected on live keys.

**Cards** — use any **future expiry date**, any **CVC**, any name. Because we use hosted Checkout
Sessions, the card is entered on PayMongo's page, not in the app.

| Scenario | Card number |
|----------|-------------|
| Success (Visa, no 3DS) | `4343 4343 4343 4345` |
| Success (Mastercard) | `5455 5900 0000 0009` |
| Requires 3DS authentication | `4120 0000 0000 0007` |
| Declined / failure | see the "failed payments" table in the PayMongo docs |

**GCash / Maya** — no test card numbers. In test mode PayMongo's hosted page shows a sandbox screen
with an **"Authorize / Success"** vs **"Fail"** button — click the outcome you want to simulate.

## Going live

- Re-do the keys in **Live mode**: new `sk_live_...` and a **new live webhook** (→ new `whsk_...`).
  Test mode and live mode have separate keys and separate webhooks.
- Update the secrets with the live values and redeploy if needed.
- Live keys require completing PayMongo's business activation.

## Security notes

- The PayMongo secret key lives only in Supabase function secrets — never in the app or `.env` shipped to clients.
- The payable amount is authoritative server-side (`booking.total_amount`), never trusted from the client.
- `create-payment-checkout` verifies the caller owns the booking (JWT user == `booking.customer_id`).
- The webhook verifies PayMongo's `Paymongo-Signature` HMAC against `PAYMONGO_WEBHOOK_SECRET`.
- Avoid putting `sk_`/`whsk_` values in shell history — prefer `supabase secrets set --env-file ./supabase/.env.production`.
