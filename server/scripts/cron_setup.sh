#!/bin/bash
# Steel Titans - Cron Setup Script
# Run this once on the server to configure automatic backups
# Usage: bash /root/scripts/cron_setup.sh

set -e

echo "=========================================="
echo "Steel Titans - Cron Setup"
echo "=========================================="

# Create scripts directory if needed
mkdir -p /root/scripts
mkdir -p /root/backups/postgresql
mkdir -p /var/log

# Make backup script executable
chmod +x /root/scripts/backup_db.sh

# Create log file if it doesn't exist
touch /var/log/steeltitans_backup.log

# Define cron job (every 6 hours: 0:00, 6:00, 12:00, 18:00)
CRON_JOB="0 */6 * * * /root/scripts/backup_db.sh >> /var/log/steeltitans_backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "backup_db.sh"; then
    echo "⚠️  Backup cron job already exists. Skipping..."
    crontab -l | grep "backup_db.sh"
else
    # Add cron job
    (crontab -l 2>/dev/null || echo "") | { cat; echo "$CRON_JOB"; } | crontab -
    echo "✅ Cron job added successfully!"
fi

echo ""
echo "Current crontab:"
echo "----------------------------------------"
crontab -l
echo "----------------------------------------"

# Test backup script (dry run info)
echo ""
echo "📋 Backup Configuration:"
echo "   - Database: steeltitans"
echo "   - Schedule: Every 6 hours (0:00, 6:00, 12:00, 18:00)"
echo "   - Retention: 7 days"
echo "   - Backup dir: /root/backups/postgresql/"
echo "   - Log file: /var/log/steeltitans_backup.log"

# Run a test backup now
echo ""
read -p "🔄 Run a test backup now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running backup..."
    /root/scripts/backup_db.sh
    echo ""
    echo "✅ Test backup completed!"
    ls -la /root/backups/postgresql/
fi

echo ""
echo "=========================================="
echo "✅ Cron setup complete!"
echo "=========================================="
