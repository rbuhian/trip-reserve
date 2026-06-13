-- Migration: 00012_messaging
-- Description: In-app messaging between customer and driver per booking (MSG-01, MSG-02, MSG-03, MSG-08)
-- One conversation per booking; messaging allowed once a driver is assigned and the
-- booking status IN ('confirmed','in_progress','completed').

BEGIN;

-- ============================================
-- CONVERSATIONS TABLE (one per booking)
-- ============================================

CREATE TABLE IF NOT EXISTS public.conversations (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id            UUID NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id           UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  driver_id             UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_message_at       TIMESTAMPTZ,
  last_message_preview  TEXT,
  customer_last_read_at TIMESTAMPTZ,
  driver_last_read_at   TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for participant lookups (booking_id already has a unique index)
CREATE INDEX IF NOT EXISTS idx_conversations_customer_id ON public.conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_driver_id ON public.conversations(driver_id);

-- ============================================
-- MESSAGES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body            TEXT NOT NULL CHECK (length(trim(body)) > 0),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for ordered message retrieval within a conversation
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id_created_at
  ON public.messages(conversation_id, created_at);

-- ============================================
-- TRIGGERS
-- ============================================

-- Auto-update updated_at on conversations (matches update_device_token_timestamp style in 00010)
CREATE OR REPLACE FUNCTION public.update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS conversations_updated_at ON public.conversations;
CREATE TRIGGER conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.update_conversation_timestamp();

-- Denormalize last message onto the parent conversation after each insert
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at,
      last_message_preview = left(NEW.body, 120),
      updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS messages_after_insert ON public.messages;
CREATE TRIGGER messages_after_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_conversation_last_message();

-- ============================================
-- REALTIME (MSG-03)
-- ============================================

-- Add messages to the supabase_realtime publication for live delivery.
-- Guarded so re-running the migration won't error if already added.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Conversations: participants can read their own conversation
CREATE POLICY "conversations_participant_read"
  ON public.conversations FOR SELECT
  USING (customer_id = auth.uid() OR driver_id = auth.uid());

-- Conversations: admins can do everything
CREATE POLICY "conversations_admin_all"
  ON public.conversations FOR ALL
  USING (is_admin());

-- INSERT/UPDATE on conversations go through SECURITY DEFINER RPCs below, so no
-- direct INSERT/UPDATE policies are granted to regular users.

-- Messages: participants of the parent conversation can read
CREATE POLICY "messages_participant_read"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND (c.customer_id = auth.uid() OR c.driver_id = auth.uid())
    )
  );

-- Messages: admins can do everything
CREATE POLICY "messages_admin_all"
  ON public.messages FOR ALL
  USING (is_admin());

-- Messages: a participant may send a message only while the booking is messageable
CREATE POLICY "messages_participant_insert"
  ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      JOIN public.bookings b ON b.id = c.booking_id
      WHERE c.id = messages.conversation_id
        AND (c.customer_id = auth.uid() OR c.driver_id = auth.uid())
        AND b.status IN ('confirmed', 'in_progress', 'completed')
    )
  );

-- ============================================
-- RPC FUNCTIONS
-- ============================================

-- Get the existing conversation for a booking, or create it.
-- Verifies the caller is the booking's customer or driver, a driver is assigned,
-- and the booking is in a messageable state.
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(p_booking_id uuid)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking  public.bookings%ROWTYPE;
  v_conv     public.conversations%ROWTYPE;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF v_booking.driver_id IS NULL THEN
    RAISE EXCEPTION 'Cannot start a conversation before a driver is assigned';
  END IF;

  IF v_booking.status NOT IN ('confirmed', 'in_progress', 'completed') THEN
    RAISE EXCEPTION 'Messaging is not allowed for booking status %', v_booking.status;
  END IF;

  IF auth.uid() <> v_booking.customer_id AND auth.uid() <> v_booking.driver_id THEN
    RAISE EXCEPTION 'Not authorized for this booking';
  END IF;

  -- Return existing conversation if present
  SELECT * INTO v_conv FROM public.conversations WHERE booking_id = p_booking_id;
  IF FOUND THEN
    RETURN v_conv;
  END IF;

  -- Insert, handling the race on the unique booking_id
  INSERT INTO public.conversations (booking_id, customer_id, driver_id)
  VALUES (p_booking_id, v_booking.customer_id, v_booking.driver_id)
  ON CONFLICT (booking_id) DO UPDATE SET updated_at = NOW()
  RETURNING * INTO v_conv;

  RETURN v_conv;
END;
$$;

-- Mark a conversation read for the calling participant.
CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv public.conversations%ROWTYPE;
BEGIN
  SELECT * INTO v_conv FROM public.conversations WHERE id = p_conversation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation not found';
  END IF;

  IF auth.uid() = v_conv.customer_id THEN
    UPDATE public.conversations
    SET customer_last_read_at = NOW()
    WHERE id = p_conversation_id;
  ELSIF auth.uid() = v_conv.driver_id THEN
    UPDATE public.conversations
    SET driver_last_read_at = NOW()
    WHERE id = p_conversation_id;
  ELSE
    RAISE EXCEPTION 'Not a participant of this conversation';
  END IF;
END;
$$;

-- Per-booking unread message counts for the calling participant.
-- Returns only conversations where the caller has at least one unread message
-- (unread = sent by the other party and created after the caller's last read).
CREATE OR REPLACE FUNCTION public.get_my_unread_counts()
RETURNS TABLE(booking_id uuid, unread_count integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.booking_id,
         COUNT(m.id)::integer AS unread_count
  FROM public.conversations c
  JOIN public.messages m ON m.conversation_id = c.id
  WHERE (c.customer_id = auth.uid() OR c.driver_id = auth.uid())
    AND m.sender_id <> auth.uid()
    AND m.created_at > COALESCE(
      CASE
        WHEN c.customer_id = auth.uid() THEN c.customer_last_read_at
        ELSE c.driver_last_read_at
      END,
      'epoch'::timestamptz
    )
  GROUP BY c.booking_id
  HAVING COUNT(m.id) > 0;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_unread_counts() TO authenticated;

COMMIT;
