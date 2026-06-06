-- Seed: Initial data for Trip Reserve
-- Run this after migrations to populate default data

-- ============================================
-- DEFAULT PRICING CONFIG
-- ============================================

INSERT INTO pricing_config (
  base_rate,
  per_km_rate,
  minimum_fare,
  cancellation_hours,
  cancellation_fee_percent,
  is_active
) VALUES (
  500.00,    -- ₱500 base rate
  15.00,     -- ₱15 per km
  300.00,    -- ₱300 minimum fare
  24,        -- 24 hours cancellation window
  20.00,     -- 20% cancellation fee
  true
);

-- ============================================
-- DEFAULT PRICING ADDONS
-- ============================================

INSERT INTO pricing_addons (name, description, addon_type, price, icon, display_order, is_active)
VALUES
  (
    'Airport Meet & Greet',
    'Driver meets you at arrival gate with name sign',
    'flat',
    200.00,
    'flight_land',
    1,
    true
  ),
  (
    'Child Safety Seat',
    'Certified child car seat for ages 0-7',
    'per_unit',
    150.00,
    'child_care',
    2,
    true
  ),
  (
    'Extra Waiting Time',
    'Additional waiting time beyond 15-minute grace period',
    'per_hour',
    100.00,
    'schedule',
    3,
    true
  ),
  (
    'Multiple Stops',
    'Add up to 3 additional stops along the route',
    'flat',
    150.00,
    'add_location',
    4,
    true
  ),
  (
    'Premium Vehicle Upgrade',
    'Upgrade to premium sedan or SUV',
    'flat',
    500.00,
    'directions_car',
    5,
    true
  );

-- ============================================
-- SAMPLE DATA NOTES
-- ============================================
-- Users are created via Supabase Auth, not direct insert
-- Vehicles, bookings, etc. are created through the app
--
-- For testing, create users via:
-- 1. Supabase Auth UI
-- 2. supabase.auth.signUp() in app
-- 3. Supabase Dashboard > Authentication > Users

-- ============================================
-- TEST DATA (Comment out for production)
-- ============================================

-- Uncomment below for development/testing
-- Make sure to create auth.users first via Supabase Auth

/*
-- After creating auth users, you can update their roles:
UPDATE users SET role = 'driver' WHERE email = 'driver@test.com';
UPDATE users SET role = 'admin' WHERE email = 'admin@test.com';

-- Sample vehicle (requires driver user)
INSERT INTO vehicles (driver_id, name, plate_number, capacity, description)
SELECT id, 'Toyota Innova 2023', 'ABC 1234', 7, 'Spacious MPV with aircon'
FROM users WHERE email = 'driver@test.com';
*/
