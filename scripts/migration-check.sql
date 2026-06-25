-- ============================================================================
-- Pre-Migration Safety Check
-- Run BEFORE any schema change to assess risk of downtime/conflict.
-- Usage: psql -U postgres -d yourdb -f migration-check.sql
-- ============================================================================

\echo '=== PRE-MIGRATION SAFETY CHECK ==='
SELECT NOW() AS check_time;

\echo ''
\echo '=== 1. Long Running Queries (may block DDL) ==='
SELECT pid, now() - query_start AS duration, state,
       LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE now() - query_start > INTERVAL '1 second'
  AND state = 'active'
  AND pid != pg_backend_pid()
ORDER BY query_start;

\echo '=== 2. Open Transactions (hold snapshots) ==='
SELECT pid, datname, usename, state,
       now() - query_start AS txn_duration,
       LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE state NOT IN ('idle')
  AND now() - query_start > INTERVAL '30 seconds'
  AND pid != pg_backend_pid()
ORDER BY query_start;

\echo '=== 3. Locks That Will Block ACCESS EXCLUSIVE ==='
SELECT pid, relation::regclass AS relname, locktype, mode,
       now() - query_start AS wait_duration,
       LEFT(query, 80) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.mode IN ('ROW_EXCLUSIVE', 'SHARE_ROW_EXCLUSIVE', 'SHARE_UPDATE_EXCLUSIVE')
  AND l.granted = true
  AND a.state = 'active'
  AND a.pid != pg_backend_pid()
ORDER BY relname;

\echo '=== 4. Replication Lag (DDL on primary may stall replicas) ==='
SELECT application_name, state, sync_state,
       pg_size_pretty(pg_wal_lsn_diff(
           pg_current_wal_lsn(),
           COALESCE(pg_last_wal_receive_lsn(), '0/0')
       )) AS receive_lag,
       pg_size_pretty(pg_wal_lsn_diff(
           pg_current_wal_lsn(),
           COALESCE(pg_last_wal_replay_lsn(), '0/0')
       )) AS replay_lag
FROM pg_stat_replication;

\echo '=== 5. Active Connections Summary ==='
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE state = 'active') AS active,
       COUNT(*) FILTER (WHERE state = 'idle') AS idle,
       COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn,
       COUNT(*) FILTER (WHERE wait_event IS NOT NULL) AS waiting
FROM pg_stat_activity
WHERE pid != pg_backend_pid();

\echo '=== 6. Recommended Lock Timeout Setting ==='
\echo '-- Run this before your migration to fail fast:'
\echo 'SET lock_timeout = ''5s'';'
\echo ''
\echo '-- Or set session-level:'
\echo 'SET SESSION lock_timeout = ''5s'';'

\echo ''
\echo '=== 7. CHECKLIST ==='
\echo '☐ All long-running queries identified and accounted for?'
\echo '☐ No idle-in-transaction sessions?'
\echo '☐ Replication lag is minimal (< 10s)?'
\echo '☐ Lock timeout set to 5s to avoid permanent blocking?'
\echo '☐ Migration tested on staging (same schema + data volume)?'
\echo '☐ Rollback script ready?'
\echo '☐ Performed during off-peak hours?'
\echo ''
\echo 'If any red flags above, DO NOT run the migration. Fix first.'
\echo '=== CHECK COMPLETE ==='
