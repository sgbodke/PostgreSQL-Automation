
#!/usr/bin/env bash

# ============================================================
# PostgreSQL Database Backup Script
# File: postgresql_backup.sh
# Purpose: Create a timestamped logical database backup
# Tool: pg_dump
# Compatible with: PostgreSQL 14-17 client tools
# ============================================================

set -Eeuo pipefail
umask 077

# ---------- Configuration ----------
DB_NAME="${1:-}"
DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5432}"
DB_USER="${PGUSER:-postgres}"

BACKUP_DIR="${BACKUP_DIR:-$HOME/postgres_backups}"
LOG_DIR="${LOG_DIR:-$HOME/postgres_backup_logs}"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"
LOG_FILE="${LOG_DIR}/postgresql_backup_${TIMESTAMP}.log"

# ---------- Validate input ----------
if [[ -z "$DB_NAME" ]]; then
    echo "Usage: $0 DATABASE_NAME"
    echo "Example: $0 batch45"
    exit 2
fi

# ---------- Create directories ----------
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# ---------- Logging ----------
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "PostgreSQL Backup Started: $(date)"
echo "Database: $DB_NAME"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "User: $DB_USER"
echo "Backup file: $BACKUP_FILE"
echo "=================================================="

# ---------- Check required tools ----------
if ! command -v pg_dump >/dev/null 2>&1; then
    echo "ERROR: pg_dump is not installed or not in PATH."
    exit 1
fi

if ! command -v pg_restore >/dev/null 2>&1; then
    echo "ERROR: pg_restore is not installed or not in PATH."
    exit 1
fi

# ---------- Check database connectivity ----------
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; then
    echo "ERROR: PostgreSQL server is not accepting connections."
    exit 1
fi

# ---------- Execute backup ----------
echo "Starting pg_dump..."

if pg_dump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    --format=custom \
    --verbose \
    --no-password \
    --file="$BACKUP_FILE"; then

    echo "Backup command completed."
else
    echo "ERROR: pg_dump failed."
    rm -f "$BACKUP_FILE"
    exit 1
fi

# ---------- Validate backup file ----------
if [[ ! -s "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup file is missing or empty."
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Verify that the archive can be read.
if pg_restore --list "$BACKUP_FILE" >/dev/null; then
    echo "Backup archive structure validation passed."
else
    echo "ERROR: Backup archive validation failed."
    rm -f "$BACKUP_FILE"
    exit 1
fi

# ---------- Report backup details ----------
echo ""
echo "Backup completed successfully."
echo "Backup file: $BACKUP_FILE"
du -h "$BACKUP_FILE"

echo "Backup log: $LOG_FILE"
echo "Finished at: $(date)"
echo "=================================================="
