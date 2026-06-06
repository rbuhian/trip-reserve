-- Migration: 00003_rls_policies
-- Description: Row Level Security policies for all tables
-- Pattern: Users see their own data, admins see everything

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if current user is driver
CREATE OR REPLACE FUNCTION is_driver()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'driver'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- USERS TABLE POLICIES
-- ============================================

-- Users can read their own profile
CREATE POLICY "users_read_own"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can read all users
CREATE POLICY "users_admin_read_all"
  ON users FOR SELECT
  USING (is_admin());

-- Admins can update all users
CREATE POLICY "users_admin_update_all"
  ON users FOR UPDATE
  USING (is_admin());

-- Drivers can see customer profiles (for their bookings)
CREATE POLICY "users_driver_read_customers"
  ON users FOR SELECT
  USING (
    is_driver() AND
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.customer_id = users.id
        AND bookings.driver_id = auth.uid()
    )
  );

-- ============================================
-- VEHICLES TABLE POLICIES
-- ============================================

-- Drivers can read their own vehicles
CREATE POLICY "vehicles_driver_read_own"
  ON vehicles FOR SELECT
  USING (driver_id = auth.uid());

-- Drivers can create their own vehicles
CREATE POLICY "vehicles_driver_create"
  ON vehicles FOR INSERT
  WITH CHECK (driver_id = auth.uid() AND is_driver());

-- Drivers can update their own vehicles
CREATE POLICY "vehicles_driver_update"
  ON vehicles FOR UPDATE
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- Drivers can delete (deactivate) their own vehicles
CREATE POLICY "vehicles_driver_delete"
  ON vehicles FOR DELETE
  USING (driver_id = auth.uid());

-- Customers can view active vehicles (for booking)
CREATE POLICY "vehicles_customer_read_active"
  ON vehicles FOR SELECT
  USING (is_active = true);

-- Admins can do everything
CREATE POLICY "vehicles_admin_all"
  ON vehicles FOR ALL
  USING (is_admin());

-- ============================================
-- BOOKINGS TABLE POLICIES
-- ============================================

-- Customers can read their own bookings
CREATE POLICY "bookings_customer_read_own"
  ON bookings FOR SELECT
  USING (customer_id = auth.uid());

-- Customers can create bookings
CREATE POLICY "bookings_customer_create"
  ON bookings FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- Customers can cancel their own pending/confirmed bookings
CREATE POLICY "bookings_customer_cancel"
  ON bookings FOR UPDATE
  USING (
    customer_id = auth.uid() AND
    status IN ('pending', 'confirmed')
  )
  WITH CHECK (
    customer_id = auth.uid() AND
    status = 'cancelled'
  );

-- Drivers can read bookings assigned to them OR pending (unassigned)
CREATE POLICY "bookings_driver_read"
  ON bookings FOR SELECT
  USING (
    is_driver() AND (
      driver_id = auth.uid() OR
      (status = 'pending' AND driver_id IS NULL)
    )
  );

-- Drivers can accept/decline pending bookings
CREATE POLICY "bookings_driver_accept"
  ON bookings FOR UPDATE
  USING (
    is_driver() AND
    status = 'pending' AND
    driver_id IS NULL
  )
  WITH CHECK (
    driver_id = auth.uid() AND
    status IN ('confirmed', 'cancelled')
  );

-- Drivers can update their assigned bookings (start/complete trip)
CREATE POLICY "bookings_driver_update_assigned"
  ON bookings FOR UPDATE
  USING (
    driver_id = auth.uid() AND
    status IN ('confirmed', 'in_progress')
  )
  WITH CHECK (
    driver_id = auth.uid()
  );

-- Admins can do everything
CREATE POLICY "bookings_admin_all"
  ON bookings FOR ALL
  USING (is_admin());

-- ============================================
-- PAYMENTS TABLE POLICIES
-- ============================================

-- Customers can read payments for their bookings
CREATE POLICY "payments_customer_read"
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = payments.booking_id
        AND bookings.customer_id = auth.uid()
    )
  );

-- System creates payments (via service role, not user)
-- Customers can create payments for their bookings
CREATE POLICY "payments_customer_create"
  ON payments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = payments.booking_id
        AND bookings.customer_id = auth.uid()
    )
  );

-- Admins can do everything
CREATE POLICY "payments_admin_all"
  ON payments FOR ALL
  USING (is_admin());

-- ============================================
-- AVAILABILITY BLOCKS TABLE POLICIES
-- ============================================

-- Drivers can read their own availability
CREATE POLICY "availability_driver_read_own"
  ON availability_blocks FOR SELECT
  USING (driver_id = auth.uid());

-- Drivers can create their own blocks
CREATE POLICY "availability_driver_create"
  ON availability_blocks FOR INSERT
  WITH CHECK (driver_id = auth.uid() AND is_driver());

-- Drivers can update their own blocks (not booking-related)
CREATE POLICY "availability_driver_update"
  ON availability_blocks FOR UPDATE
  USING (driver_id = auth.uid() AND booking_id IS NULL)
  WITH CHECK (driver_id = auth.uid());

-- Drivers can delete their own blocks (not booking-related)
CREATE POLICY "availability_driver_delete"
  ON availability_blocks FOR DELETE
  USING (driver_id = auth.uid() AND booking_id IS NULL);

-- Customers can read availability to check booking slots
CREATE POLICY "availability_customer_read"
  ON availability_blocks FOR SELECT
  USING (true);  -- Public read for availability checking

-- Admins can do everything
CREATE POLICY "availability_admin_all"
  ON availability_blocks FOR ALL
  USING (is_admin());

-- ============================================
-- PRICING CONFIG TABLE POLICIES
-- ============================================

-- Everyone can read active pricing
CREATE POLICY "pricing_config_read_active"
  ON pricing_config FOR SELECT
  USING (is_active = true);

-- Only admins can modify pricing
CREATE POLICY "pricing_config_admin_all"
  ON pricing_config FOR ALL
  USING (is_admin());

-- ============================================
-- PRICING ADDONS TABLE POLICIES
-- ============================================

-- Everyone can read active addons
CREATE POLICY "pricing_addons_read_active"
  ON pricing_addons FOR SELECT
  USING (is_active = true);

-- Only admins can modify addons
CREATE POLICY "pricing_addons_admin_all"
  ON pricing_addons FOR ALL
  USING (is_admin());

-- ============================================
-- BOOKING ADDONS TABLE POLICIES
-- ============================================

-- Customers can read addons for their bookings
CREATE POLICY "booking_addons_customer_read"
  ON booking_addons FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = booking_addons.booking_id
        AND bookings.customer_id = auth.uid()
    )
  );

-- Customers can add addons to their bookings
CREATE POLICY "booking_addons_customer_create"
  ON booking_addons FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = booking_addons.booking_id
        AND bookings.customer_id = auth.uid()
        AND bookings.status = 'pending'
    )
  );

-- Drivers can read addons for their bookings
CREATE POLICY "booking_addons_driver_read"
  ON booking_addons FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.id = booking_addons.booking_id
        AND bookings.driver_id = auth.uid()
    )
  );

-- Admins can do everything
CREATE POLICY "booking_addons_admin_all"
  ON booking_addons FOR ALL
  USING (is_admin());

-- ============================================
-- DRIVER EARNINGS TABLE POLICIES
-- ============================================

-- Drivers can read their own earnings
CREATE POLICY "earnings_driver_read_own"
  ON driver_earnings FOR SELECT
  USING (driver_id = auth.uid());

-- Admins can do everything
CREATE POLICY "earnings_admin_all"
  ON driver_earnings FOR ALL
  USING (is_admin());
