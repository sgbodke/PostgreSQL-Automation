
-- ============================================================
-- PostgreSQL Database Size Report
-- File: postgresql_database_size.sql
-- Purpose: Report database sizes and connection information
-- Compatible with: PostgreSQL 14, 15, 16, 17
-- ============================================================

\echo '===================================================='
\echo '          POSTGRESQL DATABASE SIZE REPORT'
\echo '===================================================='

-- 1. Report server and execution information
\echo ''
\echo '1. SERVER INFORMATION'

SELECT current_database() AS connected_database,
       current_user AS connected_user,
       inet_server_addr() AS server_ip,
       current_setting('server_version') AS postgres_version,
       now() AS report_generated_at;

-- 2. List all databases ordered by size
\echo ''
\echo '2. DATABASE SIZE SUMMARY'

SELECT d.datname AS database_name,
       pg_get_userbyid(d.datdba) AS database_owner,
       pg_size_pretty(pg_database_size(d.datname)) AS database_size,
       pg_database_size(d.datname) AS size_bytes,
       d.datallowconn AS allows_connections
FROM pg_database AS d
ORDER BY pg_database_size(d.datname) DESC;

-- 3. Calculate total size of all databases
\echo ''
\echo '3. TOTAL DATABASE SIZE'

SELECT pg_size_pretty(
           SUM(pg_database_size(datname))
       ) AS total_database_size,
       SUM(pg_database_size(datname)) AS total_size_bytes
FROM pg_database;

-- 4. List the five largest databases
\echo ''
\echo '4. TOP 5 LARGEST DATABASES'

SELECT datname AS database_name,
       pg_size_pretty(pg_database_size(datname)) AS database_size
FROM pg_database
ORDER BY pg_database_size(datname) DESC
LIMIT 5;

-- 5. Connection count by database
\echo ''
\echo '5. CONNECTIONS BY DATABASE'

SELECT datname AS database_name,
       COUNT(*) AS total_connections,
       COUNT(*) FILTER (
           WHERE state = 'active'
       ) AS active_connections,
       COUNT(*) FILTER (
           WHERE state = 'idle'
       ) AS idle_connections
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY datname
ORDER BY total_connections DESC;

-- 6. Database transaction statistics
\echo ''
\echo '6. DATABASE ACTIVITY STATISTICS'

SELECT datname AS database_name,
       numbackends AS current_backends,
       xact_commit AS transactions_committed,
       xact_rollback AS transactions_rolled_back,
       deadlocks,
       stats_reset
FROM pg_stat_database
WHERE datname IS NOT NULL
ORDER BY numbackends DESC;

\echo ''
\echo '===================================================='
\echo '          DATABASE SIZE REPORT COMPLETED'
\echo '===================================================='
