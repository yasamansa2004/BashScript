#!/bin/bash
set -euo pipefail

ssh -p 5566 automation@192.168.7.60 << 'FIRST_HEREDOC'
set -euo pipefail

JIRA_BACKUP_DIR="/opt/backups"
TAR_DIR="/tmp/backup"
BACKUP_SERVER="/data/backups/jira"
RSYNC_TARGET="automation@192.168.7.218:${BACKUP_SERVER}"
TIMESTAMP=$(date +"%Y_%m_%d_%H_%M_%S")

WEBHOOK_URL="https://chat.mtyn.ir/hooks/ioygas357tn6tjhwpzk7dmww6w"

sudo mkdir -p "$JIRA_BACKUP_DIR"
sudo mkdir -p "$TAR_DIR"
sudo setfacl -Rm u:automation:rwx "$JIRA_BACKUP_DIR"

log_and_notify () {
  local message="$1"
  echo "[$(date)] $message"
  curl -sf -X POST -H "Content-Type: application/json" \
    --data "{\"text\":\"[$(date)] $message\"}" \
    "$WEBHOOK_URL" || true
}

# ---------------- jira backup ----------------
log_and_notify "jira backup started..."
printf "jira backup started...\n"

JIRA_DB=jiradb
JIRA_USER=jira
JIRA_PASS=jirapassword

docker exec -e PGPASSWORD=$JIRA_PASS postgres-jira pg_dump -U $JIRA_USER -d $JIRA_DB >"$JIRA_BACKUP_DIR/JiraDB.sql"
backup_exit_code=$?

if [ $backup_exit_code -eq 0 ]; then
    log_and_notify "Jira backup successfully."
    printf "Jira backup successfully.\n"
else
    log_and_notify "Jira backup failed: $backup_exit_code."
    printf "Jira backup failed: $backup_exit_code.\n"
    exit 1
fi

sudo setfacl -Rm u:automation:rwx "$JIRA_BACKUP_DIR"

# ---------------- Confluence backup ----------------
log_and_notify "Confluencee backup started..."
printf "Confluence backup started...\n"

CONFLUENCE_DB=confluencedb
CONFLUENCE_USER=confluence
CONFLUENCE_PASS=confluencepassword

docker exec -e PGPASSWORD=$CONFLUENCE_PASS postgres-confluence \
pg_dump -U $CONFLUENCE_USER -d $CONFLUENCE_DB > "$JIRA_BACKUP_DIR/ConfluenceDB.sql"
backup_exit_code=$?

if [ $backup_exit_code -eq 0 ]; then
    log_and_notify "Jira backup successfully."
    printf "Jira backup successfully.\n"
else
    log_and_notify "Jira backup failed: $backup_exit_code."
    printf "Jira backup failed: $backup_exit_code.\n"
    exit 1
fi

sudo setfacl -Rm u:automation:rwx "$JIRA_BACKUP_DIR"


# ---------------- Eazybi  backup ----------------
log_and_notify "Ezybi backup started..."
printf "Ezybi backup started...\n"

EAZYBI_DB=eazybidb
EAZYBI_USER=eazybi
EAZYBI_PASS=eazybipassword

docker exec -e PGPASSWORD=$EAZYBI_PASS postgres-eazybi  pg_dump -U $EAZYBI_USER -d $EAZYBI_DB  >"$JIRA_BACKUP_DIR/EazybiDB.sql"
backup_exit_code=$?

if [ $backup_exit_code -eq 0 ]; then
    log_and_notify "Eaziby backup successfully."
    printf "Jira backup successfully.\n"
else
    log_and_notify "Eazybi backup failed: $backup_exit_code."
    printf "Eazybi backup failed: $backup_exit_code.\n"
    exit 1
fi

sudo setfacl -Rm u:automation:rwx "$JIRA_BACKUP_DIR"



printf "Start archive file...\n"
# Get latest GitLab backup tar created by gitlab-backup

ARCHIVE_FILE="${TAR_DIR}/Jira${TIMESTAMP}.tar.gz"

sudo tar -czf "$ARCHIVE_FILE"  "$JIRA_BACKUP_DIR"

log_and_notify "Archive created: $ARCHIVE_FILE"
printf "Archive created: $ARCHIVE_FILE"

#rsync -avzh -e "ssh -p 5566" "$ARCHIVE_FILE" automation@192.168.178.39:/home/automation/git_backups/

#------------------ S3 ------------------
log_and_notify "Uploading to S3 ..."
printf "Uploadin to S3 ..."

#ssh -p 5566  automation@192.168.178.39 "s3cmd put /home/automation/git_backups/gitlab-1_${TIMESTAMP}.tar.gz  s3://gitlab-1"
s3cmd put "$ARCHIVE_FILE" s3://jira-mtyn
upload_exit_code=$?

upload_exit_code=$?
if [ $upload_exit_code -eq 0 ]; then
    log_and_notify "Upload completed."
    printf "Upload completed."
else
    log_and_notify "Upload failed with exit code: $Upload_exit_code."
    print f "Upload failed with exit code: $Upload_exit_code."
    exit 1
fi

# ---------------- Rsync ----------------
log_and_notify "Starting rsync to backup server..."
printf "Starting rsync to backup server..."

rsync -avzh "$ARCHIVE_FILE" "$RSYNC_TARGET"

log_and_notify "Rsync completed."
printf "Rsync completed."

# ---------------- Cleanup ----------------
log_and_notify "Cleaning old backups..."
printf "Cleaning old backups..."

ls -1t ${JIRA_BACKUP_DIR}/*
ls -1t ${TAR_DIR}/*.tar.gz | tail -n +2 | xargs -r rm -f
#ssh -p 5566 automation@192.168.178.39 "rm -rf /home/automation/git_backups/gitlab-1_${TIMESTAMP}.tar.gz"
log_and_notify "Cleanup completed."
log_and_notify "Jira  backup finished ."
printf "Cleanup completed."
printf " Jira backup finished ."

FIRST_HEREDOC
