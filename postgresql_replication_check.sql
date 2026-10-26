
-- ============================================================
-- PostgreSQL Replication Health Check
-- File: postgresql_replication_check.sql
-- Purpose: Monitor streaming replication and WAL status
-- Compatible with: PostgreSQL 14, 15, 16, 17
--
-- Run on PRIMARY and STANDBY separately.
-- Execute using psql.
-- ============================================================

\echo '===================================================='
\echo '       POSTGRESQL REPLICATION HEALTH CHECK'
\echo '===================================================='

-- 1. Identify the database server role
\echo ''
\echo '1. SERVER ROLE'

SELECT inet_server_addr() AS server_ip,
       inet_server_port() AS server_port,
       current_setting('server_version') AS postgres_version,
       CASE
           WHEN pg_is_in_recovery()
           THEN 'STANDBY'
           ELSE 'PRIMARY'
       END AS server_role,
       now() AS check_timestamp;

-- 2. PRIMARY: Connected standby servers
\echo ''
\echo '2. PRIMARY - CONNECTED STANDBY STATUS'

SELECT application_name,
       client_addr,
       state,
       sync_state,
       sent_lsn,
       write_lsn,
       flush_lsn,
       replay_lsn,
       write_lag,
       flush_lag,
       replay_lag,
       reply_time
FROM pg_stat_replication
ORDER BY application_name;

-- 3. PRIMARY: Current WAL position
\echo ''
\echo '3. PRIMARY - CURRENT WAL POSITION'

SELECT pg_current_wal_lsn() AS current_wal_lsn,
       pg_size_pretty(
           pg_wal_lsn_diff(
               pg_current_wal_lsn(),
               '0/0'
           )::numeric
       ) AS cumulative_wal_position;

-- 4. PRIMARY: Replication slots
\echo ''
\echo '4. PRIMARY - REPLICATION SLOTS'

SELECT slot_name,
       slot_type,
       database,
       active,
       restart_lsn,
       confirmed_flush_lsn,
       CASE
           WHEN restart_lsn IS NOT NULL
           THEN pg_size_pretty(
               pg_wal_lsn_diff(
                   pg_current_wal_lsn(),
                   restart_lsn
               )::bigint
           )
           ELSE NULL
       END AS retained_wal_estimate
FROM pg_replication_slots
ORDER BY slot_name;

-- 5. STANDBY: WAL receiver status
\echo ''
\echo '5. STANDBY - WAL RECEIVER STATUS'

SELECT status,
       sender_host,
       sender_port,
       slot_name,
       written_lsn,
       flushed_lsn,
       received_tli,
       last_msg_send_time,
       last_msg_receipt_time,
       latest_end_lsn,
       latest_end_time
FROM pg_stat_wal_receiver;

-- 6. STANDBY: WAL replay status
\echo ''
\echo '6. STANDBY - WAL REPLAY STATUS'

SELECT pg_last_wal_receive_lsn() AS last_received_lsn,
       pg_last_wal_replay_lsn() AS last_replayed_lsn,
       pg_last_xact_replay_timestamp() AS last_replay_timestamp,
       CASE
           WHEN pg_last_wal_receive_lsn() IS NOT NULL
            AND pg_last_wal_replay_lsn() IS NOT NULL
           THEN pg_size_pretty(
               pg_wal_lsn_diff(
                   pg_last_wal_receive_lsn(),
                   pg_last_wal_replay_lsn()
               )::bigint
           )
           ELSE NULL
       END AS received_vs_replayed_wal_bytes;

-- 7. STANDBY: Replay delay estimate
\echo ''
\echo '7. STANDBY - TIME SINCE LAST REPLAYED TRANSACTION'

SELECT pg_last_xact_replay_timestamp() AS last_replayed_transaction,
       CASE
           WHEN pg_last_xact_replay_timestamp() IS NOT NULL
           THEN now() - pg_last_xact_replay_timestamp()
           ELSE NULL
       END AS time_since_last_replay;

-- 8. WAL and replication configuration
\echo ''
\echo '8. REPLICATION CONFIGURATION'

SELECT name,
       setting,
       unit,
       source
FROM pg_settings
WHERE name IN (
    'wal_level',
    'max_wal_senders',
    'max_replication_slots',
    'wal_keep_size',
    'hot_standby',
    'synchronous_commit',
    'archive_mode'
)
ORDER BY name;

\echo ''
\echo '===================================================='
\echo '       REPLICATION CHECK COMPLETED'
\echo '===================================================='
