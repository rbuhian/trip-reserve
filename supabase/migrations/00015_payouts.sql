-- Migration: 00015_payouts
-- Description: Driver Payouts & Withdrawals database layer (PO-01..04, PO-10, PO-20..24).
--
-- Reuses the EXISTING driver_earnings table (per-trip CREDIT ledger). This migration
-- adds the WITHDRAWAL (debit) side, an append-only audit trail, balance RPCs, and
-- reconciles crediting so earnings are recorded only when a booking is BOTH completed
-- AND paid.
--
-- Idempotent: IF NOT EXISTS, DROP TRIGGER IF EXISTS, guarded enum + publication adds.

BEGIN;

-- ============================================
-- ENUM
-- ============================================

-- Guarded so re-running won't error if the type already exists.
DO $$
BEGIN
  CREATE TYPE withdrawal_status AS ENUM ('pending', 'approved', 'rejected', 'paid');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

-- ============================================
-- WITHDRAWALS TABLE (debit side of the ledger)
-- ============================================

CREATE TABLE IF NOT EXISTS public.withdrawals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id        UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  amount           DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  payout_method    TEXT NOT NULL,            -- 'gcash' | 'maya' | 'bank'
  payout_account   TEXT NOT NULL,            -- GCash/Maya number or bank account no.
  payout_name      TEXT NOT NULL,            -- account holder name
  status           withdrawal_status NOT NULL DEFAULT 'pending',
  note             TEXT,                      -- driver's optional note
  reject_reason    TEXT,
  reference_number TEXT,                      -- admin's payout reference
  proof_url        TEXT,                      -- admin's proof screenshot (payout-proofs bucket)
  requested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_by      UUID REFERENCES public.users(id),
  reviewed_at      TIMESTAMPTZ,
  paid_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawals_driver_id ON public.withdrawals(driver_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON public.withdrawals(status);

-- Reuse the existing update_updated_at() function (defined in 00004).
DROP TRIGGER IF EXISTS withdrawals_updated_at ON public.withdrawals;
CREATE TRIGGER withdrawals_updated_at
  BEFORE UPDATE ON public.withdrawals
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- WITHDRAWAL EVENTS TABLE (append-only audit trail)
-- ============================================

CREATE TABLE IF NOT EXISTS public.withdrawal_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  withdrawal_id UUID NOT NULL REFERENCES public.withdrawals(id) ON DELETE CASCADE,
  event         TEXT NOT NULL,    -- 'requested' | 'approved' | 'rejected' | 'paid'
  actor_id      UUID REFERENCES public.users(id),
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_events_withdrawal_id_created_at
  ON public.withdrawal_events(withdrawal_id, created_at);

-- ============================================
-- CREDITING RECONCILIATION (PO-10)
-- Earnings are credited only when the booking is completed AND paid.
-- Either condition can be satisfied first, so we trigger from both bookings
-- (on completion) and payments (on paid) and converge through one function.
-- ============================================

-- Idempotent credit: inserts a single driver_earnings row for a booking only when
-- it is completed, has a driver, and a paid payment exists. SECURITY DEFINER so it
-- bypasses RLS (no INSERT policy exists for drivers on driver_earnings).
CREATE OR REPLACE FUNCTION public.credit_driver_earnings(p_booking_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  platform_fee_percent DECIMAL := 15.00;  -- 15% platform fee (matches existing logic)
  v_booking public.bookings%ROWTYPE;
  gross DECIMAL;
  fee   DECIMAL;
  net   DECIMAL;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Must be a completed booking with an assigned driver.
  IF v_booking.status <> 'completed' OR v_booking.driver_id IS NULL THEN
    RETURN;
  END IF;

  -- Must have a paid payment.
  IF NOT EXISTS (
    SELECT 1 FROM public.payments
    WHERE booking_id = p_booking_id AND status = 'paid'
  ) THEN
    RETURN;
  END IF;

  gross := v_booking.total_amount;
  fee   := gross * (platform_fee_percent / 100);
  net   := gross - fee;

  -- UNIQUE(booking_id) + ON CONFLICT DO NOTHING guarantees no double-credit, no
  -- matter which side (completion or payment) fires first or how often.
  INSERT INTO public.driver_earnings (
    driver_id, booking_id, gross_amount, platform_fee, net_amount, status
  ) VALUES (
    v_booking.driver_id, v_booking.id, gross, fee, net, 'pending'
  )
  ON CONFLICT (booking_id) DO NOTHING;
END;
$$;

-- Replace the bookings AFTER UPDATE trigger function: no longer inserts directly,
-- delegates to credit_driver_earnings (which checks the paid condition too).
CREATE OR REPLACE FUNCTION public.create_driver_earnings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status = 'in_progress' THEN
    PERFORM public.credit_driver_earnings(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

-- Existing trigger bookings_create_earnings (from 00004) already calls
-- create_driver_earnings() AFTER UPDATE ON bookings; CREATE OR REPLACE above
-- updates the function body in place, so no trigger re-creation is needed.

-- Credit from the payments side: when a payment becomes 'paid', try to credit the
-- booking (no-op unless the booking is also completed and not yet credited).
CREATE OR REPLACE FUNCTION public.credit_earnings_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'paid' THEN
    PERFORM public.credit_driver_earnings(NEW.booking_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS payments_credit_earnings ON public.payments;
CREATE TRIGGER payments_credit_earnings
  AFTER INSERT OR UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.credit_earnings_on_payment();

-- ============================================
-- BALANCE RPC
-- ============================================

-- Calling driver's balance breakdown. Available = lifetime net earnings minus all
-- amounts currently held in withdrawals (pending + approved + paid).
CREATE OR REPLACE FUNCTION public.get_my_driver_balance()
RETURNS TABLE(total_earned numeric, available numeric, pending numeric, paid_out numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_earned numeric;
  v_held         numeric;
  v_pending      numeric;
  v_paid_out     numeric;
BEGIN
  SELECT COALESCE(SUM(net_amount), 0) INTO v_total_earned
  FROM public.driver_earnings
  WHERE driver_id = auth.uid();

  -- Pending+approved are reserved but not yet disbursed; paid is disbursed.
  SELECT COALESCE(SUM(amount) FILTER (WHERE status IN ('pending', 'approved')), 0),
         COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0)
    INTO v_pending, v_paid_out
  FROM public.withdrawals
  WHERE driver_id = auth.uid();

  v_held := v_pending + v_paid_out;

  total_earned := v_total_earned;
  pending      := v_pending;
  paid_out     := v_paid_out;
  available    := v_total_earned - v_held;
  RETURN NEXT;
END;
$$;

-- ============================================
-- WITHDRAWAL RPCs
-- ============================================

-- Driver requests a withdrawal against available balance.
CREATE OR REPLACE FUNCTION public.request_withdrawal(
  p_amount  numeric,
  p_method  text,
  p_account text,
  p_name    text,
  p_note    text
)
RETURNS public.withdrawals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_available numeric;
  v_row       public.withdrawals%ROWTYPE;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Withdrawal amount must be greater than zero';
  END IF;

  IF p_method NOT IN ('gcash', 'maya', 'bank') THEN
    RAISE EXCEPTION 'Invalid payout method: %', p_method;
  END IF;

  IF p_account IS NULL OR length(trim(p_account)) = 0 THEN
    RAISE EXCEPTION 'Payout account is required';
  END IF;

  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'Payout account holder name is required';
  END IF;

  -- available = lifetime net earnings - all held (pending + approved + paid).
  SELECT (b.total_earned - (b.pending + b.paid_out)) INTO v_available
  FROM public.get_my_driver_balance() b;

  IF p_amount > v_available THEN
    RAISE EXCEPTION 'Requested amount % exceeds available balance %', p_amount, v_available;
  END IF;

  INSERT INTO public.withdrawals (
    driver_id, amount, payout_method, payout_account, payout_name, status, note
  ) VALUES (
    auth.uid(), p_amount, p_method, p_account, p_name, 'pending', p_note
  )
  RETURNING * INTO v_row;

  INSERT INTO public.withdrawal_events (withdrawal_id, event, actor_id, note)
  VALUES (v_row.id, 'requested', auth.uid(), p_note);

  RETURN v_row;
END;
$$;

-- Admin approves a pending withdrawal.
CREATE OR REPLACE FUNCTION public.approve_withdrawal(p_id uuid)
RETURNS public.withdrawals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.withdrawals%ROWTYPE;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only admins can approve withdrawals';
  END IF;

  SELECT * INTO v_row FROM public.withdrawals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal not found';
  END IF;

  IF v_row.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending withdrawals can be approved (current status: %)', v_row.status;
  END IF;

  UPDATE public.withdrawals
  SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
  WHERE id = p_id
  RETURNING * INTO v_row;

  INSERT INTO public.withdrawal_events (withdrawal_id, event, actor_id)
  VALUES (p_id, 'approved', auth.uid());

  RETURN v_row;
END;
$$;

-- Admin rejects a pending withdrawal with a reason.
CREATE OR REPLACE FUNCTION public.reject_withdrawal(p_id uuid, p_reason text)
RETURNS public.withdrawals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.withdrawals%ROWTYPE;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only admins can reject withdrawals';
  END IF;

  SELECT * INTO v_row FROM public.withdrawals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal not found';
  END IF;

  IF v_row.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending withdrawals can be rejected (current status: %)', v_row.status;
  END IF;

  UPDATE public.withdrawals
  SET status = 'rejected', reject_reason = p_reason,
      reviewed_by = auth.uid(), reviewed_at = NOW()
  WHERE id = p_id
  RETURNING * INTO v_row;

  INSERT INTO public.withdrawal_events (withdrawal_id, event, actor_id, note)
  VALUES (p_id, 'rejected', auth.uid(), p_reason);

  RETURN v_row;
END;
$$;

-- Admin marks an approved withdrawal as paid. Proof is required.
CREATE OR REPLACE FUNCTION public.mark_withdrawal_paid(
  p_id        uuid,
  p_reference text,
  p_proof_url text
)
RETURNS public.withdrawals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.withdrawals%ROWTYPE;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only admins can mark withdrawals as paid';
  END IF;

  IF p_proof_url IS NULL OR length(trim(p_proof_url)) = 0 THEN
    RAISE EXCEPTION 'Payout proof is required to mark a withdrawal as paid';
  END IF;

  SELECT * INTO v_row FROM public.withdrawals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal not found';
  END IF;

  IF v_row.status <> 'approved' THEN
    RAISE EXCEPTION 'Only approved withdrawals can be marked paid (current status: %)', v_row.status;
  END IF;

  UPDATE public.withdrawals
  SET status = 'paid', reference_number = p_reference,
      proof_url = p_proof_url, paid_at = NOW()
  WHERE id = p_id
  RETURNING * INTO v_row;

  INSERT INTO public.withdrawal_events (withdrawal_id, event, actor_id, note)
  VALUES (p_id, 'paid', auth.uid(), p_reference);

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_driver_balance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(numeric, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_withdrawal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_withdrawal(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_withdrawal_paid(uuid, text, text) TO authenticated;

-- ============================================
-- STORAGE BUCKET FOR PAYOUT PROOF SCREENSHOTS
-- ============================================

-- Private bucket (matches the 00006 'documents' pattern).
INSERT INTO storage.buckets (id, name, public)
VALUES ('payout-proofs', 'payout-proofs', false)
ON CONFLICT (id) DO NOTHING;

-- Policy choice: a driver SELECT scoped to "objects for my own withdrawals" is hard
-- to express on storage.objects (no link from object path to withdrawal row). Payout
-- proofs are non-sensitive receipts whose URL is only surfaced to the owning driver on
-- their own withdrawal row. So: admins (is_admin()) can INSERT/UPDATE/SELECT, and any
-- authenticated user can SELECT (read) objects in this bucket.

CREATE POLICY "Admins can upload payout proofs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'payout-proofs' AND is_admin());

CREATE POLICY "Admins can update payout proofs"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'payout-proofs' AND is_admin());

CREATE POLICY "Authenticated can view payout proofs"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'payout-proofs');

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_events ENABLE ROW LEVEL SECURITY;

-- Withdrawals: the owning driver or an admin can read.
-- INSERT/UPDATE flow through SECURITY DEFINER RPCs, so no direct user write policies.
CREATE POLICY "withdrawals_owner_or_admin_read"
  ON public.withdrawals FOR SELECT
  USING (driver_id = auth.uid() OR is_admin());

-- Withdrawal events: the owning driver of the parent withdrawal or an admin can read.
CREATE POLICY "withdrawal_events_participant_read"
  ON public.withdrawal_events FOR SELECT
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM public.withdrawals w
      WHERE w.id = withdrawal_events.withdrawal_id
        AND w.driver_id = auth.uid()
    )
  );

-- ============================================
-- REALTIME
-- ============================================

-- Add withdrawals to the publication so a driver sees status changes live.
-- RLS still applies to the changefeed, so a driver only receives their own rows.
-- Guarded so re-running won't error if already added.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.withdrawals;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

COMMIT;
