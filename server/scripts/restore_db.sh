#!/bin/bash
# Steel Titans - PostgreSQL Restore Script
# Usage: ./restore_db.sh backup_file.sql.gz

set -e

# Configuration
DB_NAME="steeltitans"
DB_USER="steeltitans_api"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo "Available backups:"
    ls -lh /root/backups/postgresql/*.sql.gz 2>/dev/null || echo "  No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Verify file exists
if [ ! -f "${BACKUP_FILE}" ]; then
    log "ERROR: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

log "WARNING: This will replace ALL data in ${DB_NAME}!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    log "Restore cancelled."
    exit 0
fi

log "Starting restore from ${BACKUP_FILE}..."

# Stop API service to prevent writes
log "Stopping API service..."
systemctl stop steeltitans-api || true

# Restore the database
log "Restoring database..."
gunzip -c "${BACKUP_FILE}" | psql -U "${DB_USER}" -h localhost "${DB_NAME}"

# Restart API service
log "Starting API service..."
systemctl start steeltitans-api || true

log "Restore completed successfully!"

exit 0
