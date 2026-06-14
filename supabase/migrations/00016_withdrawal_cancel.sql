-- Migration: 00016_withdrawal_cancel
-- Description: Let a driver cancel their OWN withdrawal while it is still pending.
-- Adds a 'cancelled' value to withdrawal_status and a SECURITY DEFINER RPC.
-- A cancelled withdrawal releases the held funds automatically, because the
-- balance "held" set in get_my_driver_balance() is ('pending','approved','paid')
-- — 'cancelled' is excluded, just like 'rejected'.

-- ADD VALUE must not be wrapped in an explicit transaction with later use of the
-- value; the function body below only references it as a text literal (plpgsql is
-- late-bound), so this is safe. IF NOT EXISTS makes the migration idempotent.
ALTER TYPE withdrawal_status ADD VALUE IF NOT EXISTS 'cancelled';

-- Driver cancels their own pending withdrawal.
CREATE OR REPLACE FUNCTION public.cancel_withdrawal(p_id uuid)
RETURNS public.withdrawals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_w public.withdrawals%ROWTYPE;
BEGIN
  SELECT * INTO v_w FROM public.withdrawals WHERE id = p_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal not found';
  END IF;

  IF v_w.driver_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to cancel this withdrawal';
  END IF;

  IF v_w.status <> 'pending' THEN
    RAISE EXCEPTION 'Only a pending withdrawal can be cancelled (current: %)', v_w.status;
  END IF;

  UPDATE public.withdrawals
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_id
  RETURNING * INTO v_w;

  INSERT INTO public.withdrawal_events (withdrawal_id, event, actor_id)
  VALUES (p_id, 'cancelled', auth.uid());

  RETURN v_w;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_withdrawal(uuid) TO authenticated;
