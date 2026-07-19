#!/bin/bash

echo "[INFO] Starting Dispatch DB backup"

ssh -i /home/automation/.ssh/id_ed25519 -o StrictHostKeyChecking=no -p 233 monitor@185.13.228.99 << 'FIRST_HEREDOC'

ssh ddb << 'SECOND_HEREDOC'

BACKUP_DIR="/var/backups/db/dispatch"
DISPATCH_DIR="$BACKUP_DIR"
RSYNC_TARGET="automation@192.168.218:/data/backups/beroozresaan/Dispatch"
TODAY_DATE=$(date +"%Y_%m_%d_%H_%M_%S")

mkdir -p "$DISPATCH_DIR"

pg_dump \
  --host="192.168.19.84" \
  --port="5432" \
  --username="postgres" \
  --format=c \
  --blobs \
  --encoding="UTF8" \
  --file="$BACKUP_DIR/Dispatch_db_${TODAY_DATE}.sql" \
  "Dispatch"

if [ ! -s "$BACKUP_DIR/Dispatch_db_${TODAY_DATE}.sql" ]; then
    echo "[ERROR] Dispatch backup failed"
    exit 1
fi

printf '%s %s\n' "$(date)" "---> Copy file to monitor"
rsync -avzh "$BACKUP_DIR"/Dispatch_db_${TODAY_DATE}.sql monitor@192.168.19.121:/home/monitor/db-backup-daily/dispatch/

printf '%s %s\n' "$(date)" "---> Send file from monitor to s3"
ssh monitor@192.168.19.121 s3cmd put /home/monitor/db-backup-daily/dispatch/Dispatch_db_${TODAY_DATE}.sql s3://beroozresaan

printf '%s %s\n' "$(date)" "---> Delete old backups"
ssh monitor@192.168.19.121 "(cd /home/monitor/db-backup-daily/dispatch/ && ls -tp | grep -v '/$' | tail -n +1 | xargs -I {} rm -- {})"

printf '%s %s\n' "$(date)" "---> Delete file from server"
rm -rf "$BACKUP_DIR"/Dispatch_db_*.sql

SECOND_HEREDOC

rsync -avz /home/monitor/db-backup-daily/dispatch/Dispatch_db_${TODAY_DATE}.sql "$RSYNC_TARGET"


ls -1t "$RSYNC_TARGET" | tail -n +4 | xargs -r -I {} rm -rf "$RSYNC_TARGET"/{}

echo "[INFO] Dispatch backup completed"

FIRST_HEREDOC
