-- UniStream: stop the client writing its own subscription state, and
-- harden the two SECURITY DEFINER functions.
--
-- Run in the Supabase SQL Editor. No client change is required — both
-- apps only ever SELECT from user_accounts (Flutter:
-- AuthService.fetchAccountInfo; tvOS: AuthService.fetchAccountInfo).

-- ============================================================
-- 1. user_accounts becomes read-only to the client
-- ============================================================
-- The old policy was `for all ... using (auth.uid() = id)`, which grants
-- UPDATE as well as SELECT. Any authenticated user could therefore run
--
--     update user_accounts
--        set subscription_tier = 'premium',
--            subscription_expires_at = '2099-01-01'
--      where id = auth.uid();
--
-- with nothing but the public anon key and their own session — granting
-- themselves the paid tier. It is inert *today* only because
-- FeatureAccess.canUse is a hard-coded `true` while the monetisation
-- rework is pending; this table is exactly what the new gates will read,
-- so the hole has to close before they land.
--
-- After this migration the only writers are:
--   * handle_new_user() below — SECURITY DEFINER, runs as the table
--     owner, which is exempt from RLS (no INSERT policy needed, and
--     adding one would re-open the write path);
--   * the revenuecat-webhook Edge Function — service role, bypasses RLS;
--   * the delete-user Edge Function — service role, same.

drop policy if exists "Users own account" on user_accounts;
drop policy if exists "Users read own account" on user_accounts;

create policy "Users read own account" on user_accounts
  for select using (auth.uid() = id);

-- ============================================================
-- 2. claim_profile_data: require a session, pin the search_path
-- ============================================================
-- Two problems with the original:
--
--   a) It accepted any p_profile_hash and claimed every orphan row
--      carrying it. profile_hash is sha256("$serverUrl:$username") —
--      guessable for a known target — so a caller could adopt someone
--      else's leftover pre-auth rows. Reachable rows are limited to the
--      legacy `user_id is null` ones (current RLS forbids creating new
--      ones), but an unauthenticated caller had no business here at all.
--
--   b) No fixed search_path. A SECURITY DEFINER function resolves its
--      table names against the *caller's* search_path, so a caller who
--      can create objects in an earlier schema can shadow `user_favorites`
--      and have the definer's rights applied to their own table.
--      (This is what Supabase's linter reports as
--      `function_search_path_mutable`.)

create or replace function claim_profile_data(p_profile_hash text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'claim_profile_data requires an authenticated session'
      using errcode = '28000';
  end if;

  if p_profile_hash is null or length(p_profile_hash) = 0 then
    return;
  end if;

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
$$;

-- EXECUTE is granted to PUBLIC by default; narrow it to signed-in users.
revoke execute on function claim_profile_data(text) from public;
grant  execute on function claim_profile_data(text) to authenticated;

-- ============================================================
-- 3. handle_new_user: pin the search_path too
-- ============================================================
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into user_accounts (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Verification:
--   Signup still creates a user_accounts row, and this must fail with
--   "new row violates row-level security policy" / 0 rows updated when
--   run from the app's anon key + a user session:
--
--     update user_accounts set subscription_tier = 'premium'
--      where id = auth.uid();
