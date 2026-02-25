#!/bin/bash
set -euo pipefail

ssh automation@192.168.178.39 -p 5566 << 'FIRST_HEREDOC'
set -euo pipefail

PORTE_BACKUP_DIR="/var/opt/backups/routaa/porte"
TAR_DIR="/tmp/backup"
RSYNC_TARGET="automation@192.168.7.218:/data/backups/routaa/Porte"
TIMESTAMP=$(date +"%Y_%m_%d_%H_%M_%S")
WEBHOOK_URL="https://chat.mtyn.ir/hooks/ioygas357tn6tjhwpzk7dmww6w"

log_and_notify() {
    local message="$1"
    echo "[$(date)] $message"
    curl -sf -X POST -H "Content-Type: application/json" \
        --data "{\"text\":\"[$(date)] $message\"}" \
        "$WEBHOOK_URL" || true
}

printf '%s\n' "Backup start"
log_and_notify "Porte backup started..."

sudo mkdir -p "$PORTE_BACKUP_DIR" "$TAR_DIR"

sudo setfacl -Rm u:automation:rwx "$PORTE_BACKUP_DIR"
sudo setfacl -Rm u:automation:rwx "$TAR_DIR"

DUMP_FILE="$PORTE_BACKUP_DIR/Porte_${TIMESTAMP}.sql"
ARCHIVE_FILE="$TAR_DIR/Porte_${TIMESTAMP}.tar.gz"

pg_dump\
  --file "$DUMP_FILE" \
  --host "192.168.178.39" \
  --port "5432" \
  --username "automation" \
  --role "postgres" \
  --format=c \
  --blobs \
  --encoding="UTF8" \
  "porte"

if [ ! -s "$DUMP_FILE" ]; then
    log_and_notify "Porte backup FAILED!"
    printf "porte backup FAILED!"
    exit 1
fi

tar -czf "$ARCHIVE_FILE" -C "$PORTE_BACKUP_DIR" "$(basename "$DUMP_FILE")"

if [ ! -s "$ARCHIVE_FILE" ]; then
    log_and_notify "Compression failed!"
    printf "Compression failed!"
    exit 1
fi

#..............S3................
log_and_notify "Uploading on S3..."
printf "Uploading on S3..."

s3cmd put "$ARCHIVE_FILE" s3://routaa

upload_exit_code=$?
if [ $upload_exit_code -eq 0 ]; then
    log_and_notify "Upload completed."
    printf "Upload completed."
else
    log_and_notify "Upload failed with exit code: $Upload_exit_code."
    print f "Upload failed with exit code: $Upload_exit_code."
    exit 1
fi


log_and_notify "Rsync started..."
printf "Rsync started..."

rsync -avzh "$ARCHIVE_FILE" "$RSYNC_TARGET"

log_and_notify "Rsync completed."
printf "Rsync completed."

log_and_notify "Cleaning old backups..."
printf "Cleaning old backups..."

ls -1t "$TAR_DIR"/*.tar.gz | tail -n +2 | xargs -r rm -f
ls -1t "$PORTE_BACKUP_DIR"/*.sql | tail -n +1 | xargs -r rm -f

log_and_notify "Cleaning old backup completed"
log_and_notify "Backup completed successfully."
printf "Cleaning old backup completed" 
printf "Backup completed successfully."

FIRST_HEREDOC
