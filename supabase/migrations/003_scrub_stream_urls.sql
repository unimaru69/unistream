-- UniStream: scrub Xtream credentials out of user_watch_progress.meta_json
--
-- WHY
-- Xtream stream URLs carry the panel login and password in their path:
--     {server}/movie/{username}/{password}/{id}.mkv
-- Until this migration, both clients pushed the watch-progress meta blob
-- verbatim, `url` key included — so every user's IPTV subscription
-- credentials sat in cleartext in `user_watch_progress.meta_json`. RLS
-- scoped those rows per user; it did not keep them secret from a database
-- dump, a backup, dashboard access or a leaked service-role key.
--
-- The clients no longer send `url` (Flutter: SyncService.scrubMetaForSync;
-- tvOS: SyncService.pushProgress). This migration removes the copies
-- already stored, and salvages the container extension into the `ext` key
-- that replaced the URL — so Continue Watching keeps resuming .mkv / .ts
-- items cross-device instead of falling back to .mp4 and 404ing.
--
-- Run it in the Supabase SQL Editor AFTER both clients are released.
-- Running it earlier is harmless but older builds will re-add URLs until
-- their users update; re-run it then.
--
-- Idempotent: re-running it changes nothing once the rows are clean.
--
-- NOTE ON SHAPES: `meta_json` is a jsonb column, but PostgREST stores what
-- the client sent. Both clients JSON-*encode* the map before sending, so
-- most rows hold a jsonb **string** containing an encoded object rather
-- than a jsonb object. Both shapes are handled below (the clients'
-- decoders tolerate both too).

do $$
declare
  r         record;
  decoded   jsonb;
  v_url     text;
  v_ext     text;
  cleaned   jsonb;
  n_scrubbed integer := 0;
  n_ext      integer := 0;
  n_skipped  integer := 0;
begin
  for r in
    select id, meta_json
      from user_watch_progress
     -- Two renderings to match: a jsonb object renders the key as "url",
     -- while a jsonb string (an encoded object, which is what both
     -- clients actually sent) renders it with the quotes escaped, as
     -- \"url\". Matching only the first form silently skips most rows.
     -- strpos rather than LIKE: LIKE treats \ as its escape character,
     -- so the second pattern would raise "invalid escape sequence".
     where strpos(meta_json::text, '"url"')   > 0
        or strpos(meta_json::text, '\"url\"') > 0
  loop
    begin
      -- Normalise both shapes down to a jsonb object.
      if jsonb_typeof(r.meta_json) = 'object' then
        decoded := r.meta_json;
      elsif jsonb_typeof(r.meta_json) = 'string' then
        decoded := (r.meta_json #>> '{}')::jsonb;
      else
        continue;
      end if;

      if jsonb_typeof(decoded) <> 'object'
         or not jsonb_exists(decoded, 'url') then
        continue;
      end if;

      v_url   := decoded ->> 'url';
      cleaned := decoded - 'url';

      -- Salvage the container extension the URL was carrying, unless the
      -- row already has one from a newer client.
      if (cleaned ->> 'ext') is null or (cleaned ->> 'ext') = '' then
        v_ext := lower(substring(v_url from '\.([A-Za-z0-9]{1,5})$'));
        if v_ext is not null and v_ext <> '' then
          cleaned := cleaned || jsonb_build_object('ext', v_ext);
          n_ext := n_ext + 1;
        end if;
      end if;

      -- Write back in the same shape the row was stored in, so clients
      -- that special-case one or the other keep working.
      if jsonb_typeof(r.meta_json) = 'object' then
        update user_watch_progress set meta_json = cleaned where id = r.id;
      else
        update user_watch_progress
           set meta_json = to_jsonb(cleaned::text)
         where id = r.id;
      end if;

      n_scrubbed := n_scrubbed + 1;
    exception when others then
      -- A malformed blob must not abort the whole scrub.
      n_skipped := n_skipped + 1;
      raise notice 'skipped row % (%): %', r.id, sqlstate, sqlerrm;
    end;
  end loop;

  raise notice 'meta_json scrub: % row(s) cleaned, % given a salvaged ext, % skipped',
    n_scrubbed, n_ext, n_skipped;
end $$;

-- Preflight (run before, to size the blast radius) and verification (run
-- after — must return 0):
--
--   select count(*) from user_watch_progress
--    where strpos(meta_json::text, '"url"')   > 0
--       or strpos(meta_json::text, '\"url\"') > 0;
