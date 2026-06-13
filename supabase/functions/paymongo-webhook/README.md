# paymongo-webhook Edge Function

Receives PayMongo webhook events and reconciles the matching `payments` row.
Handles `checkout_session.payment.paid` / `payment.paid` (→ `paid`) and
`payment.failed` (→ `failed`). Always responds `200 { received: true }` for
handled or ignored events so PayMongo does not retry.

## Signature verification

The `Paymongo-Signature` header has the form `t=<timestamp>,te=<sig>,li=<sig>`
(`te` = test mode, `li` = live mode). We compute
`HMAC-SHA256(key = PAYMONGO_WEBHOOK_SECRET, msg = "<t>.<rawBody>")` as hex (via
Deno `crypto.subtle.importKey` / `sign`) and compare it, in constant time,
against the `te` and `li` values; a match on either is accepted.

- If `PAYMONGO_WEBHOOK_SECRET` is **unset**, verification is **skipped** with a
  warning (graceful local/testing mode).
- If it is **set** and the signature does not match → `401`.

## Payment row matching

In resolution order:
1. `metadata.payment_id` on the resource (set when the checkout session was
   created) — most reliable.
2. Otherwise match `checkout_session_id == resource.id` (the `cs_...` id on a
   `checkout_session.*` event) **or** `external_id == resource.id`.

The PayMongo payment id stored in `external_id` on a paid event is taken from the
nested `attributes.payments[]` array when present (checkout-session events),
falling back to the resource id.

## Setup

Deploy the function (no JWT — PayMongo calls it unauthenticated, so deploy with
`--no-verify-jwt`):
```
supabase functions deploy paymongo-webhook --no-verify-jwt
```

Required secrets:
```
supabase secrets set PAYMONGO_SECRET_KEY=sk_test_xxx
supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsk_xxx
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by the platform.

## Register the webhook

In the **PayMongo Dashboard → Developers → Webhooks**, register this function's
URL:
```
https://<project-ref>.supabase.co/functions/v1/paymongo-webhook
```
Subscribe it to at least these events:
- `checkout_session.payment.paid`
- `payment.failed`

(`payment.paid` is also handled if subscribed.) Copy the webhook signing secret
shown on creation into `PAYMONGO_WEBHOOK_SECRET`.
