#!/bin/bash
# Steel Titans - PostgreSQL Backup Script
# Run with cron: 0 */6 * * * /root/scripts/backup_db.sh
# Keeps last 7 days of backups

set -e

# Configuration
DB_NAME="steeltitans"
DB_USER="steeltitans_api"
BACKUP_DIR="/root/backups/postgresql"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting backup of ${DB_NAME}..."

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Perform backup with pg_dump
log "Running pg_dump..."
pg_dump -U "${DB_USER}" -h localhost "${DB_NAME}" | gzip > "${BACKUP_FILE}"

# Verify backup was created
if [ -f "${BACKUP_FILE}" ]; then
    SIZE=$(ls -lh "${BACKUP_FILE}" | awk '{print $5}')
    log "Backup created successfully: ${BACKUP_FILE} (${SIZE})"
else
    log "ERROR: Backup file was not created!"
    exit 1
fi

# Remove old backups
log "Removing backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

# Count remaining backups
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/${DB_NAME}_*.sql.gz 2>/dev/null | wc -l)
log "Total backups: ${BACKUP_COUNT}"

log "Backup completed successfully!"

# Optional: Upload to remote storage (uncomment and configure)
# S3_BUCKET="your-bucket-name"
# aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/backups/postgresql/"

exit 0
