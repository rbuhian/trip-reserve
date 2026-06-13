# create-payment-checkout Edge Function

Creates a **PayMongo Hosted Checkout** session for a booking and returns the
checkout URL the customer is redirected to. The booking amount is taken
server-side from `bookings.total_amount` (never trusted from the client).

## Contract

`POST` with a customer's Supabase JWT in the `Authorization: Bearer <jwt>` header.

Request body:
```json
{ "bookingId": "<uuid>", "method": "gcash" | "card" | "paymaya" }
```

Success response — `200`:
```json
{ "checkoutUrl": "https://checkout.paymongo.com/...", "paymentId": "<uuid>" }
```

Error responses:
- `400` — missing `bookingId`, invalid `method`, or non-positive amount
- `401` — missing/invalid JWT
- `403` — caller does not own the booking
- `404` — booking not found
- `502` — PayMongo rejected the checkout session (payment row marked `failed`)
- `500` — server/config error

## Flow

1. Validate body and map our method to PayMongo `payment_method_types`.
2. Resolve the caller via `supabase.auth.getUser(jwt)` and confirm
   `booking.customer_id` matches the user id.
3. Compute `centavos = round(total_amount * 100)`.
4. Insert a `payments` row (`status: 'pending'`).
5. `POST /checkout_sessions` to PayMongo with the booking line item and
   `metadata.booking_id` + `metadata.payment_id`.
6. Persist `checkout_session_id` + `external_source_id` (the `cs_...` id) on the
   payment row and flip it to `processing`.

## Setup

Deploy the function:
```
supabase functions deploy create-payment-checkout
```

Required secrets:
```
supabase secrets set PAYMONGO_SECRET_KEY=sk_test_xxx
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by the platform.

Optional secrets (defaults shown):
```
supabase secrets set PAYMENT_SUCCESS_URL=https://tripreserve.ph/payment/success
supabase secrets set PAYMENT_CANCEL_URL=https://tripreserve.ph/payment/cancel
```

The secret key is never logged.
