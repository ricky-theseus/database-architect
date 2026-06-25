-- ============================================================================
-- Database Diagnostics — one-stop health check
-- Usage: psql -U postgres -d yourdb -f diagnostics.sql
-- Tested on: PostgreSQL 14+
-- ============================================================================

\echo '=== 1. Slow Queries (top 20 by total time) ==='
SELECT query, calls, ROUND(total_exec_time::numeric / 1000, 2) AS total_sec,
       ROUND(total_exec_time::numeric / calls, 2) AS avg_ms,
       ROUND(shared_blks_hit * 100.0 / NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS hit_ratio,
       rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 20;

\echo '=== 2. Unused Indexes (idx_scan < 100) ==='
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan < 100
  AND indexrelid NOT IN (SELECT conindid FROM pg_constraint WHERE contype = 'p')
ORDER BY idx_scan ASC, tablename;

\echo '=== 3. Missing Indexes (seq scans on large tables) ==='
SELECT schemaname, relname, seq_scan, seq_tup_read, n_live_tup
FROM pg_stat_user_tables
WHERE seq_scan > 1000 AND n_live_tup > 10000
ORDER BY seq_tup_read DESC LIMIT 20;

\echo '=== 4. Current Locks & Blocked Queries ==='
SELECT blocked.pid AS blocked_pid,
       blocking.pid AS blocking_pid,
       blocked.query AS blocked_query,
       blocking.query AS blocking_query,
       AGE(now(), blocked.query_start) AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.state = 'active';

\echo '=== 5. Long Running Transactions (> 5 min) ==='
SELECT pid, state, now() - query_start AS duration,
       LEFT(query, 120) AS query_preview, wait_event, wait_event_type
FROM pg_stat_activity
WHERE now() - query_start > INTERVAL '5 minutes'
  AND state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY query_start;

\echo '=== 6. Idle in Transaction (holds snapshots, prevents vacuum) ==='
SELECT pid, datname, usename, state, now() - state_change AS idle_duration,
       LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > INTERVAL '1 minute'
ORDER BY state_change;

\echo '=== 7. Connection Count by State ==='
SELECT state, COUNT(*) AS count
FROM pg_stat_activity
WHERE pid != pg_backend_pid()
GROUP BY state
ORDER BY count DESC;

\echo '=== 8. Connection Usage vs Max ==='
SELECT COUNT(*) AS used, setting::int AS max,
       ROUND(COUNT(*) * 100.0 / setting::int, 1) AS pct
FROM pg_stat_activity, pg_settings
WHERE name = 'max_connections'
  AND pid != pg_backend_pid()
GROUP BY setting;

\echo '=== 9. Table Bloat Estimate (top 20) ==='
SELECT schemaname, tablename,
       n_live_tup AS live_rows,
       n_dead_tup AS dead_rows,
       ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       ROUND(last_autovacuum::text::timestamp, 0) AS last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC LIMIT 20;

\echo '=== 10. Vacuum & Analyze Activity ==='
SELECT schemaname, relname, last_autovacuum, last_autoanalyze,
       n_dead_tup, n_mod_since_analyze
FROM pg_stat_user_tables
WHERE last_autovacuum IS NULL
   OR last_autoanalyze IS NULL
   OR n_dead_tup > 10000
ORDER BY n_dead_tup DESC;

\echo '=== 11. Replication Lag (if replica) ==='
SELECT CASE WHEN NOT pg_is_in_recovery() THEN 'Primary — no lag'
       ELSE 'Replica — see below' END AS status;
SELECT application_name, state, sync_state,
       pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()) AS replay_lag_bytes
FROM pg_stat_replication;

\echo '=== 12. Cache Hit Ratio ==='
SELECT 'shared_buffers' AS pool,
       ROUND(sum(blks_hit) * 100.0 / NULLIF(sum(blks_hit + blks_read), 0), 2) AS hit_ratio_pct
FROM pg_stat_database;

\echo '=== 13. Index vs Table Size (top 20 bloated) ==='
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total,
       pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes,
       ROUND(pg_indexes_size(schemaname||'.'||tablename) * 100.0 /
             NULLIF(pg_total_relation_size(schemaname||'.'||tablename), 0), 1) AS idx_pct
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 20;

\echo '=== 14. Settings Summary ==='
SELECT name, setting, unit, boot_val, context
FROM pg_settings
WHERE name IN ('shared_buffers', 'effective_cache_size', 'work_mem',
               'maintenance_work_mem', 'random_page_cost', 'max_connections',
               'wal_buffers', 'autovacuum_vacuum_scale_factor',
               'autovacuum_vacuum_cost_limit', 'autovacuum_naptime');

\echo '=== Done. Review the red flags above and fix accordingly. ==='
