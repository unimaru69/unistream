-- UniStream Supabase Schema
-- Run this in the Supabase SQL Editor

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

-- Favorites & Watchlist
create table if not exists user_favorites (
  id uuid default uuid_generate_v4() primary key,
  profile_hash text not null,
  item_key text not null,
  item_json jsonb not null default '{}',
  list_type text not null default 'favorite', -- 'favorite' or 'watchlist'
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  unique(profile_hash, item_key, list_type)
);

-- Custom Collections
create table if not exists user_collections (
  id uuid default uuid_generate_v4() primary key,
  profile_hash text not null,
  collection_id text not null,
  name text not null,
  mode text not null default 'live',
  items_json jsonb not null default '[]',
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  unique(profile_hash, collection_id)
);

-- Watch Progress & History
create table if not exists user_watch_progress (
  id uuid default uuid_generate_v4() primary key,
  profile_hash text not null,
  content_key text not null,
  position_ms bigint not null default 0,
  duration_ms bigint not null default 0,
  meta_json jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique(profile_hash, content_key)
);

-- User Settings (theme, locale, etc.)
create table if not exists user_settings (
  id uuid default uuid_generate_v4() primary key,
  profile_hash text not null,
  setting_key text not null,
  value_json jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique(profile_hash, setting_key)
);

-- ============================================================
-- INDEXES for fast queries by profile_hash
-- ============================================================
create index if not exists idx_favorites_profile on user_favorites(profile_hash);
create index if not exists idx_collections_profile on user_collections(profile_hash);
create index if not exists idx_progress_profile on user_watch_progress(profile_hash);
create index if not exists idx_settings_profile on user_settings(profile_hash);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
-- Enable RLS on all tables
alter table user_favorites enable row level security;
alter table user_collections enable row level security;
alter table user_watch_progress enable row level security;
alter table user_settings enable row level security;

-- Allow all operations via anon key (security via profile_hash opacity)
-- The profile_hash is a SHA-256 of serverUrl:username, practically unguessable
create policy "Allow all for anon" on user_favorites for all using (true) with check (true);
create policy "Allow all for anon" on user_collections for all using (true) with check (true);
create policy "Allow all for anon" on user_watch_progress for all using (true) with check (true);
create policy "Allow all for anon" on user_settings for all using (true) with check (true);

-- ============================================================
-- REALTIME
-- ============================================================
-- Enable realtime for all tables (for cross-device sync)
alter publication supabase_realtime add table user_favorites;
alter publication supabase_realtime add table user_collections;
alter publication supabase_realtime add table user_watch_progress;
alter publication supabase_realtime add table user_settings;
