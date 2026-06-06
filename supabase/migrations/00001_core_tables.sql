-- Migration: 00001_core_tables
-- Description: Create core tables for Trip Reserve
-- Tables: users, vehicles, bookings, payments

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE user_role AS ENUM ('customer', 'driver', 'admin');

CREATE TYPE booking_status AS ENUM (
  'pending',      -- Awaiting driver acceptance
  'confirmed',    -- Driver accepted, awaiting trip
  'in_progress',  -- Trip started
  'completed',    -- Trip finished
  'cancelled'     -- Cancelled by any party
);

CREATE TYPE payment_status AS ENUM (
  'pending',
  'processing',
  'paid',
  'failed',
  'refunded'
);

CREATE TYPE payment_method AS ENUM (
  'gcash',
  'card',
  'maya'
);

-- ============================================
-- USERS TABLE
-- ============================================
-- Extends Supabase auth.users with profile data

CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  role user_role NOT NULL DEFAULT 'customer',
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE users IS 'User profiles extending Supabase auth';
COMMENT ON COLUMN users.role IS 'User role: customer, driver, or admin';

-- ============================================
-- VEHICLES TABLE
-- ============================================

CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,                    -- e.g., "Toyota Innova 2023"
  plate_number TEXT NOT NULL,
  capacity INTEGER NOT NULL DEFAULT 4,   -- Passenger capacity
  image_url TEXT,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_capacity CHECK (capacity > 0 AND capacity <= 50)
);

COMMENT ON TABLE vehicles IS 'Vehicles owned/operated by drivers';
COMMENT ON COLUMN vehicles.capacity IS 'Maximum passenger capacity';

-- Unique plate number per active vehicle
CREATE UNIQUE INDEX vehicles_plate_number_unique
  ON vehicles(plate_number)
  WHERE is_active = true;

-- ============================================
-- BOOKINGS TABLE
-- ============================================

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_number TEXT NOT NULL UNIQUE,

  -- Parties
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  driver_id UUID REFERENCES users(id) ON DELETE RESTRICT,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE RESTRICT,

  -- Status
  status booking_status NOT NULL DEFAULT 'pending',

  -- Locations
  pickup_address TEXT NOT NULL,
  pickup_lat DECIMAL(10, 8) NOT NULL,
  pickup_lng DECIMAL(11, 8) NOT NULL,
  dropoff_address TEXT NOT NULL,
  dropoff_lat DECIMAL(10, 8) NOT NULL,
  dropoff_lng DECIMAL(11, 8) NOT NULL,

  -- Trip details
  distance_km DECIMAL(10, 2) NOT NULL,
  duration_minutes INTEGER NOT NULL,
  scheduled_date DATE NOT NULL,
  pickup_time TIME NOT NULL,

  -- Pricing (in PHP)
  base_fare DECIMAL(10, 2) NOT NULL,
  distance_fee DECIMAL(10, 2) NOT NULL,
  addons_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(10, 2) NOT NULL,

  -- Timestamps
  confirmed_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_distance CHECK (distance_km > 0),
  CONSTRAINT valid_duration CHECK (duration_minutes > 0),
  CONSTRAINT valid_total CHECK (total_amount >= 0)
);

COMMENT ON TABLE bookings IS 'Trip bookings from customers';
COMMENT ON COLUMN bookings.reference_number IS 'Human-readable booking reference (e.g., TR-ABC123)';

-- ============================================
-- PAYMENTS TABLE
-- ============================================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,

  -- Payment details
  amount DECIMAL(10, 2) NOT NULL,
  method payment_method NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',

  -- External payment gateway reference
  external_id TEXT,              -- PayMongo payment ID
  external_source_id TEXT,       -- PayMongo source ID (for GCash)

  -- Metadata
  paid_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  failure_reason TEXT,
  refunded_at TIMESTAMPTZ,
  refund_reason TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_amount CHECK (amount > 0)
);

COMMENT ON TABLE payments IS 'Payment records for bookings';
COMMENT ON COLUMN payments.external_id IS 'PayMongo payment/transaction ID';

-- ============================================
-- ENABLE RLS (Policies defined in separate migration)
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
