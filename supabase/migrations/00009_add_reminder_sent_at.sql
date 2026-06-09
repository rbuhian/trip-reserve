-- Migration: 00009_add_reminder_sent_at
-- Description: Add reminder_sent_at column to bookings table to track
--              whether a trip reminder email has been sent to the customer.
--              Used by the send-trip-reminders edge function (CUST-42).

BEGIN;

-- Add reminder_sent_at to track whether a trip reminder email has been sent
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ NULL DEFAULT NULL;

COMMENT ON COLUMN public.bookings.reminder_sent_at IS
  'Timestamp when the 2-hour trip reminder email was sent to the customer. NULL means reminder has not been sent yet.';

-- Index to make the cron query fast (only unnotified upcoming confirmed bookings)
CREATE INDEX IF NOT EXISTS idx_bookings_reminder
  ON public.bookings (status, scheduled_date, reminder_sent_at)
  WHERE status = 'confirmed' AND reminder_sent_at IS NULL;

COMMIT;
