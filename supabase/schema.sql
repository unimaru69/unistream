-- UniStream Supabase Schema — consolidated, secure-by-default state
--
-- Run this in the Supabase SQL Editor for a fresh setup. It includes
-- everything that migrations/001_add_auth.sql and 002_add_subscription_fields.sql
-- apply, so a clone+paste of this file yields the same DB you'd get by
-- running the original schema then both migrations in order.
--
-- IMPORTANT: this schema requires Supabase Auth. Enable Email + Apple
-- providers in the dashboard before running.

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ============================================================
-- TABLES (sync data, scoped per authenticated user)
-- ============================================================

-- Favorites & Watchlist
create table if not exists user_favorites (
  id           uuid default uuid_generate_v4() primary key,
  user_id      uuid references auth.users(id) on delete cascade,
  profile_hash text not null,
  item_key     text not null,
  item_json    jsonb not null default '{}',
  list_type    text not null default 'favorite', -- 'favorite' | 'watchlist'
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,
  unique(user_id, profile_hash, item_key, list_type)
);

-- Custom Collections
create table if not exists user_collections (
  id            uuid default uuid_generate_v4() primary key,
  user_id       uuid references auth.users(id) on delete cascade,
  profile_hash  text not null,
  collection_id text not null,
  name          text not null,
  mode          text not null default 'live',
  items_json    jsonb not null default '[]',
  updated_at    timestamptz not null default now(),
  deleted       boolean not null default false,
  unique(user_id, profile_hash, collection_id)
);

-- Watch Progress & History
create table if not exists user_watch_progress (
  id           uuid default uuid_generate_v4() primary key,
  user_id      uuid references auth.users(id) on delete cascade,
  profile_hash text not null,
  content_key  text not null,
  position_ms  bigint not null default 0,
  duration_ms  bigint not null default 0,
  meta_json    jsonb not null default '{}',
  updated_at   timestamptz not null default now(),
  unique(user_id, profile_hash, content_key)
);

-- User Settings (theme, locale, etc.)
create table if not exists user_settings (
  id           uuid default uuid_generate_v4() primary key,
  user_id      uuid references auth.users(id) on delete cascade,
  profile_hash text not null,
  setting_key  text not null,
  value_json   jsonb not null default '{}',
  updated_at   timestamptz not null default now(),
  unique(user_id, profile_hash, setting_key)
);

-- ============================================================
-- USER ACCOUNTS — trial tracking + subscription state
-- ============================================================
create table if not exists user_accounts (
  id                       uuid primary key references auth.users(id) on delete cascade,
  email                    text,
  trial_started_at         timestamptz not null default now(),
  subscription_tier        text not null default 'trial',
  subscription_expires_at  timestamptz,
  cross_platform_license   boolean not null default false,
  -- RevenueCat integration
  revenuecat_customer_id   text,
  subscription_platform    text,
  subscription_product_id  text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_favorites_user      on user_favorites(user_id);
create index if not exists idx_favorites_profile   on user_favorites(profile_hash);
create index if not exists idx_collections_user    on user_collections(user_id);
create index if not exists idx_collections_profile on user_collections(profile_hash);
create index if not exists idx_progress_user       on user_watch_progress(user_id);
create index if not exists idx_progress_profile    on user_watch_progress(profile_hash);
create index if not exists idx_settings_user       on user_settings(user_id);
create index if not exists idx_settings_profile    on user_settings(profile_hash);
create index if not exists idx_accounts_tier       on user_accounts(subscription_tier);
create index if not exists idx_accounts_revenuecat on user_accounts(revenuecat_customer_id)
  where revenuecat_customer_id is not null;

-- ============================================================
-- ROW LEVEL SECURITY — every row is scoped to its owner
-- ============================================================
alter table user_favorites       enable row level security;
alter table user_collections     enable row level security;
alter table user_watch_progress  enable row level security;
alter table user_settings        enable row level security;
alter table user_accounts        enable row level security;

-- Each row is readable / writable only by the user who owns it.
-- The anon key is harmless against this — auth.uid() is null when
-- unauthenticated, so unauthenticated requests match no rows.
create policy "Users own data" on user_favorites
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own data" on user_collections
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own data" on user_watch_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own data" on user_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own account" on user_accounts
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- ============================================================
-- TRIGGER — auto-create user_accounts row on signup
-- ============================================================
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into user_accounts (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- RPC — claim orphaned pre-auth data for a profile_hash
-- ============================================================
-- Called once after a user signs in to a device that already had local
-- sync data under an anonymous profile_hash, so the records get bound
-- to their auth.users id and the RLS policies above start matching.
create or replace function claim_profile_data(p_profile_hash text)
returns void as $$
begin
  update user_favorites
    set user_id = auth.uid()
    where profile_hash = p_profile_hash and user_id is null;

  update user_collections
    set user_id = auth.uid()
    where profile_hash = p_profile_hash and user_id is null;

  update user_watch_progress
    set user_id = auth.uid()
    where profile_hash = p_profile_hash and user_id is null;

  update user_settings
    set user_id = auth.uid()
    where profile_hash = p_profile_hash and user_id is null;
end;
$$ language plpgsql security definer;

-- ============================================================
-- REALTIME — enable cross-device sync over the pubsub channel
-- ============================================================
alter publication supabase_realtime add table user_favorites;
alter publication supabase_realtime add table user_collections;
alter publication supabase_realtime add table user_watch_progress;
alter publication supabase_realtime add table user_settings;
