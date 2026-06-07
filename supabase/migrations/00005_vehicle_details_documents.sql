-- Migration: 00005_vehicle_details_documents
-- Description: Add vehicle details (year, model, color) and document management
-- Tables: vehicles (alter), vehicle_photos, documents

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE document_type AS ENUM (
  'drivers_license',
  'vehicle_or',           -- Official Receipt
  'vehicle_cr',           -- Certificate of Registration
  'vehicle_photo_front',
  'vehicle_photo_back',
  'vehicle_photo_left',
  'vehicle_photo_right',
  'vehicle_photo_interior'
);

CREATE TYPE document_status AS ENUM (
  'pending',      -- Awaiting review
  'approved',     -- Verified by admin
  'rejected',     -- Rejected, needs resubmission
  'expired'       -- Document expired
);

-- ============================================
-- ALTER VEHICLES TABLE
-- ============================================

ALTER TABLE vehicles
  ADD COLUMN year INTEGER,
  ADD COLUMN model TEXT,
  ADD COLUMN color TEXT;

COMMENT ON COLUMN vehicles.year IS 'Vehicle manufacture year';
COMMENT ON COLUMN vehicles.model IS 'Vehicle model (e.g., Innova, Fortuner)';
COMMENT ON COLUMN vehicles.color IS 'Vehicle color';

-- Add constraint for valid year
ALTER TABLE vehicles
  ADD CONSTRAINT valid_year CHECK (year IS NULL OR (year >= 1990 AND year <= EXTRACT(YEAR FROM CURRENT_DATE) + 1));

-- ============================================
-- VEHICLE PHOTOS TABLE
-- ============================================

CREATE TABLE vehicle_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  photo_type document_type NOT NULL,
  storage_path TEXT NOT NULL,       -- Path in Supabase Storage
  url TEXT NOT NULL,                -- Public/signed URL
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_photo_type CHECK (
    photo_type IN ('vehicle_photo_front', 'vehicle_photo_back', 'vehicle_photo_left', 'vehicle_photo_right', 'vehicle_photo_interior')
  )
);

COMMENT ON TABLE vehicle_photos IS 'Vehicle photos (front, back, sides, interior)';

-- Only one photo of each type per vehicle
CREATE UNIQUE INDEX vehicle_photos_type_unique
  ON vehicle_photos(vehicle_id, photo_type);

-- ============================================
-- DOCUMENTS TABLE
-- ============================================

CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,  -- NULL for driver documents

  document_type document_type NOT NULL,
  status document_status NOT NULL DEFAULT 'pending',

  storage_path TEXT NOT NULL,       -- Path in Supabase Storage
  url TEXT NOT NULL,                -- Public/signed URL
  file_name TEXT NOT NULL,          -- Original filename
  file_size INTEGER,                -- Size in bytes
  mime_type TEXT,                   -- e.g., 'image/jpeg', 'application/pdf'

  -- Document-specific metadata
  document_number TEXT,             -- License number, OR/CR number
  expiry_date DATE,                 -- For licenses

  -- Review
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT vehicle_doc_requires_vehicle CHECK (
    (document_type IN ('vehicle_or', 'vehicle_cr') AND vehicle_id IS NOT NULL) OR
    (document_type NOT IN ('vehicle_or', 'vehicle_cr'))
  )
);

COMMENT ON TABLE documents IS 'User and vehicle documents (licenses, OR/CR)';
COMMENT ON COLUMN documents.storage_path IS 'Path in Supabase Storage bucket';
COMMENT ON COLUMN documents.expiry_date IS 'Document expiration date for tracking';

-- Index for efficient lookups
CREATE INDEX documents_user_id_idx ON documents(user_id);
CREATE INDEX documents_vehicle_id_idx ON documents(vehicle_id) WHERE vehicle_id IS NOT NULL;
CREATE INDEX documents_status_idx ON documents(status);

-- Only one active document of each type per user/vehicle
CREATE UNIQUE INDEX documents_user_type_unique
  ON documents(user_id, document_type)
  WHERE vehicle_id IS NULL AND status != 'rejected';

CREATE UNIQUE INDEX documents_vehicle_type_unique
  ON documents(vehicle_id, document_type)
  WHERE vehicle_id IS NOT NULL AND status != 'rejected';

-- ============================================
-- ENABLE RLS
-- ============================================

ALTER TABLE vehicle_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Vehicle Photos: Drivers can manage their own vehicle photos
CREATE POLICY "Drivers can view their vehicle photos"
  ON vehicle_photos FOR SELECT
  USING (
    vehicle_id IN (
      SELECT id FROM vehicles WHERE driver_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can insert their vehicle photos"
  ON vehicle_photos FOR INSERT
  WITH CHECK (
    vehicle_id IN (
      SELECT id FROM vehicles WHERE driver_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can update their vehicle photos"
  ON vehicle_photos FOR UPDATE
  USING (
    vehicle_id IN (
      SELECT id FROM vehicles WHERE driver_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can delete their vehicle photos"
  ON vehicle_photos FOR DELETE
  USING (
    vehicle_id IN (
      SELECT id FROM vehicles WHERE driver_id = auth.uid()
    )
  );

-- Customers can view vehicle photos (for booking display)
CREATE POLICY "Customers can view vehicle photos"
  ON vehicle_photos FOR SELECT
  USING (true);

-- Documents: Users can manage their own documents
CREATE POLICY "Users can view their documents"
  ON documents FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their documents"
  ON documents FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their documents"
  ON documents FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete their documents"
  ON documents FOR DELETE
  USING (user_id = auth.uid());

-- Admins can view and manage all documents
CREATE POLICY "Admins can view all documents"
  ON documents FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update all documents"
  ON documents FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- STORAGE BUCKETS
-- ============================================
-- Note: Storage buckets and policies are in migration 00006
