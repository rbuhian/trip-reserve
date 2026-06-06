-- Migration: 00004_indexes_triggers
-- Description: Performance indexes, triggers, and functions

-- ============================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER vehicles_updated_at
  BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER availability_blocks_updated_at
  BEFORE UPDATE ON availability_blocks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER pricing_config_updated_at
  BEFORE UPDATE ON pricing_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER pricing_addons_updated_at
  BEFORE UPDATE ON pricing_addons
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER driver_earnings_updated_at
  BEFORE UPDATE ON driver_earnings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- USER PROFILE AUTO-CREATION
-- ============================================
-- Automatically create user profile when auth.users record is created

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'customer'::public.user_role)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- BOOKING REFERENCE NUMBER GENERATION
-- ============================================

CREATE OR REPLACE FUNCTION generate_booking_reference()
RETURNS TRIGGER AS $$
DECLARE
  new_reference TEXT;
  reference_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate reference: TR-XXXXXX (6 alphanumeric chars)
    new_reference := 'TR-' || upper(substring(md5(random()::text) from 1 for 6));

    -- Check if exists
    SELECT EXISTS (
      SELECT 1 FROM bookings WHERE reference_number = new_reference
    ) INTO reference_exists;

    EXIT WHEN NOT reference_exists;
  END LOOP;

  NEW.reference_number := new_reference;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_generate_reference
  BEFORE INSERT ON bookings
  FOR EACH ROW
  WHEN (NEW.reference_number IS NULL)
  EXECUTE FUNCTION generate_booking_reference();

-- ============================================
-- AUTO-BLOCK AVAILABILITY ON BOOKING CONFIRM
-- ============================================

CREATE OR REPLACE FUNCTION auto_block_on_booking_confirm()
RETURNS TRIGGER AS $$
BEGIN
  -- When booking is confirmed, create availability block
  IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
    INSERT INTO availability_blocks (
      driver_id,
      vehicle_id,
      block_date,
      start_time,
      end_time,
      is_full_day,
      reason,
      booking_id
    ) VALUES (
      NEW.driver_id,
      NEW.vehicle_id,
      NEW.scheduled_date,
      NEW.pickup_time,
      (NEW.pickup_time + (NEW.duration_minutes || ' minutes')::INTERVAL)::TIME,
      false,
      'booked',
      NEW.id
    );
  END IF;

  -- When booking is cancelled, remove the block
  IF NEW.status = 'cancelled' AND OLD.status IN ('pending', 'confirmed') THEN
    DELETE FROM availability_blocks
    WHERE booking_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_auto_block
  AFTER UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION auto_block_on_booking_confirm();

-- ============================================
-- DRIVER EARNINGS AUTO-CREATE ON COMPLETION
-- ============================================

CREATE OR REPLACE FUNCTION create_driver_earnings()
RETURNS TRIGGER AS $$
DECLARE
  platform_fee_percent DECIMAL := 15.00;  -- 15% platform fee
  gross DECIMAL;
  fee DECIMAL;
  net DECIMAL;
BEGIN
  -- When booking is completed, create earnings record
  IF NEW.status = 'completed' AND OLD.status = 'in_progress' THEN
    gross := NEW.total_amount;
    fee := gross * (platform_fee_percent / 100);
    net := gross - fee;

    INSERT INTO driver_earnings (
      driver_id,
      booking_id,
      gross_amount,
      platform_fee,
      net_amount,
      status
    ) VALUES (
      NEW.driver_id,
      NEW.id,
      gross,
      fee,
      net,
      'pending'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_create_earnings
  AFTER UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION create_driver_earnings();

-- ============================================
-- PERFORMANCE INDEXES
-- ============================================

-- Users
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);

-- Vehicles
CREATE INDEX idx_vehicles_driver ON vehicles(driver_id);
CREATE INDEX idx_vehicles_active ON vehicles(is_active) WHERE is_active = true;

-- Bookings
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_driver ON bookings(driver_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_date ON bookings(scheduled_date);
CREATE INDEX idx_bookings_customer_status ON bookings(customer_id, status);
CREATE INDEX idx_bookings_driver_status ON bookings(driver_id, status);
CREATE INDEX idx_bookings_reference ON bookings(reference_number);

-- Payments
CREATE INDEX idx_payments_booking ON payments(booking_id);
CREATE INDEX idx_payments_status ON payments(status);

-- Availability
CREATE INDEX idx_availability_driver ON availability_blocks(driver_id);
CREATE INDEX idx_availability_date ON availability_blocks(block_date);
CREATE INDEX idx_availability_driver_date ON availability_blocks(driver_id, block_date);

-- Earnings
CREATE INDEX idx_earnings_driver ON driver_earnings(driver_id);
CREATE INDEX idx_earnings_status ON driver_earnings(status);
CREATE INDEX idx_earnings_driver_status ON driver_earnings(driver_id, status);
