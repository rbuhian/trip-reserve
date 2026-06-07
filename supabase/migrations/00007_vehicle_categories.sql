-- Migration: 00007_vehicle_categories
-- Description: Add vehicle categories with category-based pricing
-- Changes: vehicle_category enum, vehicles.category, bookings fields, category_pricing table

-- ============================================
-- VEHICLE CATEGORY ENUM
-- ============================================

CREATE TYPE vehicle_category AS ENUM (
  'sedan',      -- Standard sedan (4 passengers)
  'mpv_suv',    -- MPV/SUV (6-7 passengers)
  'van'         -- Van (10-15 passengers)
);

-- ============================================
-- ADD CATEGORY TO VEHICLES
-- ============================================

ALTER TABLE vehicles
  ADD COLUMN category vehicle_category NOT NULL DEFAULT 'sedan';

COMMENT ON COLUMN vehicles.category IS 'Vehicle category: sedan, mpv_suv, or van';

-- ============================================
-- ADD BOOKING FIELDS FOR CATEGORY
-- ============================================

-- Add category, num_bags, and additional_info to bookings
ALTER TABLE bookings
  ADD COLUMN category vehicle_category NOT NULL DEFAULT 'sedan',
  ADD COLUMN num_bags INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN additional_info TEXT;

COMMENT ON COLUMN bookings.category IS 'Selected vehicle category for this booking';
COMMENT ON COLUMN bookings.num_bags IS 'Number of bags customer will bring';
COMMENT ON COLUMN bookings.additional_info IS 'Optional additional information from customer';

-- Add constraint for num_bags
ALTER TABLE bookings
  ADD CONSTRAINT valid_num_bags CHECK (num_bags >= 0 AND num_bags <= 20);

-- ============================================
-- CATEGORY PRICING TABLE
-- ============================================
-- Pricing configuration per vehicle category

CREATE TABLE category_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category vehicle_category NOT NULL UNIQUE,

  -- Pricing
  base_rate DECIMAL(10, 2) NOT NULL,      -- Base fare in PHP
  per_km_rate DECIMAL(10, 2) NOT NULL,    -- Per kilometer rate
  minimum_fare DECIMAL(10, 2) NOT NULL,   -- Minimum fare

  -- Metadata
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_category_rates CHECK (base_rate >= 0 AND per_km_rate >= 0),
  CONSTRAINT valid_category_minimum CHECK (minimum_fare >= 0)
);

COMMENT ON TABLE category_pricing IS 'Pricing configuration per vehicle category';

-- Insert default pricing for each category
INSERT INTO category_pricing (category, base_rate, per_km_rate, minimum_fare) VALUES
  ('sedan', 500.00, 15.00, 300.00),
  ('mpv_suv', 700.00, 20.00, 400.00),
  ('van', 1000.00, 25.00, 600.00);

-- ============================================
-- ENABLE RLS ON NEW TABLE
-- ============================================

ALTER TABLE category_pricing ENABLE ROW LEVEL SECURITY;

-- Anyone can read category pricing
CREATE POLICY "Anyone can view category pricing"
  ON category_pricing FOR SELECT
  USING (true);

-- Only admins can modify category pricing
CREATE POLICY "Admins can manage category pricing"
  ON category_pricing FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX vehicles_category_idx ON vehicles(category);
CREATE INDEX bookings_category_idx ON bookings(category);
CREATE INDEX category_pricing_active_idx ON category_pricing(is_active) WHERE is_active = true;
