-- UniStream: Add Supabase Auth integration
-- Run this migration AFTER enabling Email + Apple auth providers in Dashboard

-- ============================================================
-- 1. Add user_id column to all existing tables
-- ============================================================

ALTER TABLE user_favorites
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE user_collections
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE user_watch_progress
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- Indexes for fast queries by user_id
CREATE INDEX IF NOT EXISTS idx_favorites_user ON user_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_user ON user_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_progress_user ON user_watch_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_settings_user ON user_settings(user_id);

-- ============================================================
-- 2. Drop old unique constraints and create new ones with user_id
-- ============================================================

-- Drop old unique constraints (profile_hash only)
ALTER TABLE user_favorites
  DROP CONSTRAINT IF EXISTS user_favorites_profile_hash_item_key_list_type_key;
ALTER TABLE user_collections
  DROP CONSTRAINT IF EXISTS user_collections_profile_hash_collection_id_key;
ALTER TABLE user_watch_progress
  DROP CONSTRAINT IF EXISTS user_watch_progress_profile_hash_content_key_key;
ALTER TABLE user_settings
  DROP CONSTRAINT IF EXISTS user_settings_profile_hash_setting_key_key;

-- New unique constraints with user_id
ALTER TABLE user_favorites
  ADD CONSTRAINT uq_favorites_user_profile_item
  UNIQUE (user_id, profile_hash, item_key, list_type);

ALTER TABLE user_collections
  ADD CONSTRAINT uq_collections_user_profile_col
  UNIQUE (user_id, profile_hash, collection_id);

ALTER TABLE user_watch_progress
  ADD CONSTRAINT uq_progress_user_profile_content
  UNIQUE (user_id, profile_hash, content_key);

ALTER TABLE user_settings
  ADD CONSTRAINT uq_settings_user_profile_key
  UNIQUE (user_id, profile_hash, setting_key);

-- ============================================================
-- 3. Replace RLS policies — secure by auth.uid()
-- ============================================================

DROP POLICY IF EXISTS "Allow all for anon" ON user_favorites;
DROP POLICY IF EXISTS "Allow all for anon" ON user_collections;
DROP POLICY IF EXISTS "Allow all for anon" ON user_watch_progress;
DROP POLICY IF EXISTS "Allow all for anon" ON user_settings;

CREATE POLICY "Users own data" ON user_favorites
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users own data" ON user_collections
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users own data" ON user_watch_progress
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users own data" ON user_settings
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4. User accounts table (trial tracking, subscription state)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_accounts (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  trial_started_at timestamptz NOT NULL DEFAULT now(),
  subscription_tier text NOT NULL DEFAULT 'trial',
  subscription_expires_at timestamptz,
  cross_platform_license boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE user_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own account" ON user_accounts
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE INDEX IF NOT EXISTS idx_accounts_tier ON user_accounts(subscription_tier);

-- ============================================================
-- 5. Auto-create user_accounts row on signup
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_accounts (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 6. RPC: Claim orphaned pre-auth data for a profile_hash
-- ============================================================

CREATE OR REPLACE FUNCTION claim_profile_data(p_profile_hash text)
RETURNS void AS $$
BEGIN
  UPDATE user_favorites
    SET user_id = auth.uid()
    WHERE profile_hash = p_profile_hash AND user_id IS NULL;

  UPDATE user_collections
    SET user_id = auth.uid()
    WHERE profile_hash = p_profile_hash AND user_id IS NULL;

  UPDATE user_watch_progress
    SET user_id = auth.uid()
    WHERE profile_hash = p_profile_hash AND user_id IS NULL;

  UPDATE user_settings
    SET user_id = auth.uid()
    WHERE profile_hash = p_profile_hash AND user_id IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
