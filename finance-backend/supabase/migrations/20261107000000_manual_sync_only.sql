-- Sync only when the owner opens the app.
--
-- Removes the scheduled data jobs added by 20260919000000_server_side_scheduler.sql:
--   pocketlens-hourly-sync  (:07 hourly, POST /internal/sync)
--   pocketlens-daily        (09:20 UTC, POST /internal/daily: reconcile + digests)
--   pocketlens-wake-api     (:02 hourly, only existed to warm the API for the :07 sync)
--
-- Banks now sync from the web app instead: on open, and when its tab comes back
-- into view, for any bank not synced in the last 15 minutes (useAutoSyncOnOpen in
-- web/src/data/hooks.ts), plus the Sync button. Plaid webhooks still trigger a
-- sync when Plaid reports new data.
--
-- Kept: pocketlens-keep-awake (/health every 10 min, 15:00–06:59 UTC). It changes
-- no data; it keeps the free-tier API warm so opening the app is quick. Also kept:
-- the /internal/* endpoints and private.pocketlens_call_api, so re-enabling a
-- schedule is one cron.schedule(...) call (see the earlier migration).
--
-- Idempotent, and safe whether or not the earlier migration was ever applied:
-- does nothing when pg_cron is not installed or a job is already gone. Can be run
-- from `supabase db push` or pasted into the SQL editor.

do $$
declare
  j text;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    return;
  end if;
  foreach j in array array['pocketlens-hourly-sync', 'pocketlens-daily', 'pocketlens-wake-api'] loop
    if exists (select 1 from cron.job where jobname = j) then
      perform cron.unschedule(j);
    end if;
  end loop;
end
$$;
