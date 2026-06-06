-- Migration: 00002_supporting_tables
-- Description: Create supporting tables for Trip Reserve
-- Tables: availability_blocks, pricing_config, pricing_addons, booking_addons, driver_earnings

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE block_reason AS ENUM (
  'vacation',
  'maintenance',
  'personal',
  'booked',      -- Auto-blocked due to confirmed booking
  'other'
);

CREATE TYPE addon_type AS ENUM (
  'flat',        -- Flat fee (e.g., airport meet & greet)
  'per_hour',    -- Per hour (e.g., extra waiting)
  'per_unit'     -- Per unit (e.g., child seat)
);

CREATE TYPE earning_status AS ENUM (
  'pending',     -- Trip completed, awaiting payout
  'paid',        -- Paid to driver
  'cancelled'    -- Booking was cancelled
);

-- ============================================
-- AVAILABILITY BLOCKS TABLE
-- ============================================
-- Drivers block time when unavailable

CREATE TABLE availability_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,

  -- Block period
  block_date DATE NOT NULL,
  start_time TIME,              -- NULL = full day block
  end_time TIME,                -- NULL = full day block
  is_full_day BOOLEAN NOT NULL DEFAULT true,

  -- Reason
  reason block_reason NOT NULL DEFAULT 'personal',
  notes TEXT,

  -- If blocked due to booking
  booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_time_range CHECK (
    is_full_day = true OR (start_time IS NOT NULL AND end_time IS NOT NULL AND start_time < end_time)
  )
);

COMMENT ON TABLE availability_blocks IS 'Time blocks when drivers are unavailable';
COMMENT ON COLUMN availability_blocks.is_full_day IS 'True if entire day is blocked';

-- Prevent duplicate full-day blocks
CREATE UNIQUE INDEX availability_blocks_full_day_unique
  ON availability_blocks(driver_id, vehicle_id, block_date)
  WHERE is_full_day = true;

-- ============================================
-- PRICING CONFIG TABLE
-- ============================================
-- Global pricing configuration (admin managed)

CREATE TABLE pricing_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Base pricing
  base_rate DECIMAL(10, 2) NOT NULL DEFAULT 500.00,      -- Base fare in PHP
  per_km_rate DECIMAL(10, 2) NOT NULL DEFAULT 15.00,     -- Per kilometer rate

  -- Minimum fare
  minimum_fare DECIMAL(10, 2) NOT NULL DEFAULT 300.00,

  -- Cancellation policy
  cancellation_hours INTEGER NOT NULL DEFAULT 24,         -- Hours before trip for free cancellation
  cancellation_fee_percent DECIMAL(5, 2) NOT NULL DEFAULT 20.00,

  -- Active flag (only one config should be active)
  is_active BOOLEAN NOT NULL DEFAULT true,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_rates CHECK (base_rate >= 0 AND per_km_rate >= 0),
  CONSTRAINT valid_minimum CHECK (minimum_fare >= 0),
  CONSTRAINT valid_cancellation CHECK (cancellation_hours >= 0 AND cancellation_fee_percent >= 0 AND cancellation_fee_percent <= 100)
);

COMMENT ON TABLE pricing_config IS 'Global pricing configuration';

-- Only one active config
CREATE UNIQUE INDEX pricing_config_active_unique
  ON pricing_config(is_active)
  WHERE is_active = true;

-- ============================================
-- PRICING ADDONS TABLE
-- ============================================
-- Optional add-on services

CREATE TABLE pricing_addons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  name TEXT NOT NULL,                                     -- e.g., "Airport Meet & Greet"
  description TEXT,

  addon_type addon_type NOT NULL DEFAULT 'flat',
  price DECIMAL(10, 2) NOT NULL,                          -- Price in PHP

  -- Display
  icon TEXT,                                              -- Icon name/code
  display_order INTEGER NOT NULL DEFAULT 0,

  is_active BOOLEAN NOT NULL DEFAULT true,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_price CHECK (price >= 0)
);

COMMENT ON TABLE pricing_addons IS 'Optional add-on services customers can select';

-- ============================================
-- BOOKING ADDONS TABLE
-- ============================================
-- Junction table for bookings and their selected addons

CREATE TABLE booking_addons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  addon_id UUID NOT NULL REFERENCES pricing_addons(id) ON DELETE RESTRICT,

  -- Snapshot pricing at time of booking
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10, 2) NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_quantity CHECK (quantity > 0),
  CONSTRAINT valid_prices CHECK (unit_price >= 0 AND total_price >= 0),
  UNIQUE(booking_id, addon_id)
);

COMMENT ON TABLE booking_addons IS 'Add-ons selected for each booking';

-- ============================================
-- DRIVER EARNINGS TABLE
-- ============================================
-- Track driver earnings from completed trips

CREATE TABLE driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,

  -- Earnings breakdown
  gross_amount DECIMAL(10, 2) NOT NULL,                   -- Total booking amount
  platform_fee DECIMAL(10, 2) NOT NULL,                   -- Platform commission
  net_amount DECIMAL(10, 2) NOT NULL,                     -- Driver's share

  -- Payout
  status earning_status NOT NULL DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  payout_reference TEXT,                                  -- Bank transfer reference

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_amounts CHECK (gross_amount >= 0 AND platform_fee >= 0 AND net_amount >= 0),
  UNIQUE(booking_id)
);

COMMENT ON TABLE driver_earnings IS 'Earnings records for drivers';
COMMENT ON COLUMN driver_earnings.platform_fee IS 'Platform commission deducted from gross';

-- ============================================
-- ENABLE RLS
-- ============================================

ALTER TABLE availability_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;
