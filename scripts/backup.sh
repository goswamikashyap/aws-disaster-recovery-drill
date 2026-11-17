#!/bin/bash
set -e

PRIMARY_BUCKET=$1
DR_BUCKET=$2

if [ -z "$PRIMARY_BUCKET" ] || [ -z "$DR_BUCKET" ]; then
    echo "Usage: ./scripts/backup.sh <primary-s3-bucket> <dr-s3-bucket>"
    exit 1
fi

echo "📦 Taking real PostgreSQL binary dump (pg_dump)..."
PGPASSWORD=ProdSecret2026! pg_dump -h 127.0.0.1 -U postgres -d ordersdb -Fc -f /tmp/ordersdb.dump
DUMP_SIZE=$(du -h /tmp/ordersdb.dump | awk '{print $1}')

echo "☁️ Uploading dump ($DUMP_SIZE) to Primary S3 (ap-south-1) & syncing to DR S3 (ap-southeast-1)..."
aws s3 cp /tmp/ordersdb.dump "s3://$PRIMARY_BUCKET/pg_backups/ordersdb.dump" --region ap-south-1
aws s3 sync "s3://$PRIMARY_BUCKET/pg_backups/" "s3://$DR_BUCKET/pg_backups/" --source-region ap-south-1 --region ap-southeast-1
date +%s > /tmp/last_backup_ts.txt
echo "✅ Real PostgreSQL backup safely replicated to Singapore DR region!"
