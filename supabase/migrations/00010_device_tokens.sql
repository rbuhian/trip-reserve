-- Migration: 00010_device_tokens
-- Description: Store FCM device tokens per user for push notification delivery (INF-08 / CUST-43)

BEGIN;

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token        TEXT NOT NULL,
  platform     TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, token)
);

-- Index for fast lookup by user when sending notifications
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

-- Auto-update updated_at on upsert
CREATE OR REPLACE FUNCTION public.update_device_token_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.update_device_token_timestamp();

-- Enable RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own tokens
CREATE POLICY "users_own_device_tokens_select" ON public.device_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_own_device_tokens_insert" ON public.device_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_device_tokens_delete" ON public.device_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Service role (edge functions) can read all tokens to send notifications
-- This is handled implicitly by the service role bypassing RLS.

COMMIT;
