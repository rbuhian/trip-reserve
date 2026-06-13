-- Migration: 00014_payments_checkout
-- Description: DB prep for PayMongo Hosted Checkout payments (INF-05/CUST-23).
-- Adds the PayMongo Checkout Session id to payments so the webhook can look the
-- payment up, indexes it, and enables Realtime so the client can watch a payment
-- row flip to 'paid' after the webhook updates it via the service role.

BEGIN;

-- ============================================
-- CHECKOUT SESSION ID COLUMN
-- ============================================

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS checkout_session_id TEXT;

COMMENT ON COLUMN public.payments.checkout_session_id IS
  'PayMongo Checkout Session id (cs_...). Set when the hosted checkout session is created; used by the webhook to locate the payment row to update.';

-- ============================================
-- INDEXES
-- ============================================

-- Lookup by checkout session id (webhook path).
CREATE INDEX IF NOT EXISTS idx_payments_checkout_session_id
  ON public.payments(checkout_session_id);

-- NOTE: booking_id is already indexed by idx_payments_booking (migration 00004),
-- so no booking_id index is added here.

-- ============================================
-- REALTIME (INF-05 / CUST-23)
-- ============================================

-- Add payments to the supabase_realtime publication so the client can watch a
-- payment row flip to 'paid' after the webhook updates it.
-- Guarded so re-running the migration won't error if already added.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

-- ============================================
-- RLS DEPENDENCY NOTE (verify, don't duplicate)
-- ============================================

-- Realtime delivery to a customer depends on the existing "payments_customer_read"
-- SELECT policy (migration 00003): Postgres applies RLS to Realtime changefeeds, so
-- a customer only receives a payment row update if that SELECT policy allows the row.
-- The webhook updates rows via the service role, which bypasses RLS, so no new
-- UPDATE policy for users is required here.

COMMIT;
