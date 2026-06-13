-- Migration: 00013_customer_read_driver
-- Description: Allow a customer to read the profile of the driver assigned to
--              their booking. Mirror of the existing "users_driver_read_customers"
--              policy (00003). Without this, the driver join on the customer's
--              booking queries returns NULL under RLS, which hid the driver's
--              name on the booking details screen and disabled the "Message
--              driver" chat entry point (MSG-04).

BEGIN;

-- Customers can read driver profiles for drivers assigned to their bookings
CREATE POLICY "users_customer_read_drivers"
  ON public.users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings
      WHERE bookings.driver_id = users.id
        AND bookings.customer_id = auth.uid()
    )
  );

COMMIT;
