
-- ============================================================
-- PostgreSQL DBA Health Check Script
-- File: postgresql_health_check.sql
-- Purpose: Basic PostgreSQL database health assessment
-- Compatible with: PostgreSQL 14, 15, 16, 17
-- ============================================================

\echo '===================================================='
\echo '        POSTGRESQL DATABASE HEALTH CHECK'
\echo '===================================================='

-- 1. Database and server information
\echo ''
\echo '1. DATABASE AND SERVER INFORMATION'

SELECT version() AS postgresql_version,
       current_database() AS database_name,
       current_user AS connected_user,
       inet_server_addr() AS server_ip,
       inet_server_port() AS server_port,
       now() AS check_timestamp;

-- 2. Database sizes
\echo ''
\echo '2. DATABASE SIZES'

SELECT datname AS database_name,
       pg_size_pretty(pg_database_size(datname)) AS database_size
FROM pg_database
WHERE datallowconn = true
ORDER BY pg_database_size(datname) DESC;

-- 3. Connection usage
\echo ''
\echo '3. CONNECTION STATUS'

SELECT current_setting('max_connections') AS max_connections,
       count(*) AS total_connections,
       count(*) FILTER (WHERE state = 'active') AS active_connections,
       count(*) FILTER (WHERE state = 'idle') AS idle_connections,
       count(*) FILTER (
           WHERE wait_event_type IS NOT NULL
       ) AS waiting_sessions
FROM pg_stat_activity;

-- 4. Active queries running longer than 5 minutes
\echo ''
\echo '4. LONG-RUNNING ACTIVE QUERIES (> 5 MINUTES)'

SELECT pid,
       usename AS username,
       datname AS database_name,
       now() - query_start AS query_duration,
       state,
       left(query, 200) AS query_text
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start IS NOT NULL
  AND now() - query_start > interval '5 minutes'
  AND pid <> pg_backend_pid()
ORDER BY query_start;

-- 5. Blocking sessions
\echo ''
\echo '5. BLOCKED SESSIONS'

SELECT blocked.pid AS blocked_pid,
       blocked.usename AS blocked_user,
       blocked.wait_event_type,
       blocked.wait_event,
       blocker.pid AS blocker_pid,
       blocker.usename AS blocker_user,
       left(blocked.query, 150) AS blocked_query
FROM pg_stat_activity AS blocked
CROSS JOIN LATERAL
     unnest(pg_blocking_pids(blocked.pid)) AS b(blocker_pid)
JOIN pg_stat_activity AS blocker
  ON blocker.pid = b.blocker_pid
ORDER BY blocked.pid;

-- 6. Replication status
\echo ''
\echo '6. REPLICATION STATUS'

SELECT CASE
         WHEN pg_is_in_recovery()
           THEN 'STANDBY'
         ELSE 'PRIMARY'
       END AS server_role;

-- On a primary, display connected standby information.
SELECT application_name,
       client_addr,
       state,
       sync_state,
       write_lag,
       flush_lag,
       replay_lag
FROM pg_stat_replication;

-- On a standby, display WAL receiver status.
SELECT status,
       sender_host,
       sender_port,
       last_msg_receipt_time,
       latest_end_lsn
FROM pg_stat_wal_receiver;

-- 7. Long-running transactions
\echo ''
\echo '7. TRANSACTIONS OPEN LONGER THAN 10 MINUTES'

SELECT pid,
       usename AS username,
       datname AS database_name,
       now() - xact_start AS transaction_duration,
       state,
       left(query, 150) AS query_text
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND now() - xact_start > interval '10 minutes'
  AND pid <> pg_backend_pid()
ORDER BY xact_start;

-- 8. Deadlocks since statistics were last reset
\echo ''
\echo '8. DATABASE DEADLOCK COUNTS'

SELECT datname AS database_name,
       deadlocks,
       stats_reset
FROM pg_stat_database
WHERE datname = current_database();

-- 9. Database cache hit ratio
\echo ''
\echo '9. DATABASE CACHE HIT RATIO'

SELECT datname AS database_name,
       round(
         100.0 * blks_hit /
         NULLIF(blks_hit + blks_read, 0), 2
       ) AS cache_hit_ratio_percent
FROM pg_stat_database
WHERE datname = current_database();

\echo ''
\echo '===================================================='
\echo '        HEALTH CHECK COMPLETED'
\echo '===================================================='
