#!/bin/bash
set -euo pipefail

ssh automation@192.168.7.152 << 'FIRST_HEREDOC'
set -euo pipefail

GITLAB_BACKUP_DIR="/var/opt/gitlab/backups"
TAR_DIR="/tmp/backup"
BACKUP_SERVER="/data/backups/gitlab/gitlab_1"
RSYNC_TARGET="automation@192.168.7.218:${BACKUP_SERVER}"
TIMESTAMP=$(date +"%Y_%m_%d_%H_%M_%S")

WEBHOOK_URL="https://chat.mtyn.ir/hooks/ioygas357tn6tjhwpzk7dmww6w"

sudo mkdir -p "$TAR_DIR"

log_and_notify () {
  local message="$1"
  echo "[$(date)] $message"
  curl -sf -X POST -H "Content-Type: application/json" \
    --data "{\"text\":\"[$(date)] $message\"}" \
    "$WEBHOOK_URL" || true
}

# ---------------- GitLab backup ----------------
log_and_notify "GitLab backup started..."
printf "GitLab backup started...\n"

sudo gitlab-backup create
backup_exit_code=$?

if [ $backup_exit_code -eq 0 ]; then
    log_and_notify "GitLab backup created successfully."
    printf "GitLab backup created successfully.\n"
else
    log_and_notify "GitLab backup failed: $backup_exit_code."
    printf "GitLab backup failed: $backup_exit_code.\n"
    exit 1
fi

sudo setfacl -Rm u:automation:rwx "$GITLAB_BACKUP_DIR"
printf "Start archive file...\n"
# Get latest GitLab backup tar created by gitlab-backup
LATEST_BACKUP=$(ls -t ${GITLAB_BACKUP_DIR}/*.tar | head -n1)

if [ -z "$LATEST_BACKUP" ]; then
    log_and_notify "No GitLab backup file found!"
    printf "No GitLab backup file found!: $backup_exit_code.\n"
    exit 1
fi

ARCHIVE_FILE="${TAR_DIR}/gitlab-1_${TIMESTAMP}.tar.gz"

sudo tar -czf "$ARCHIVE_FILE" \
    /etc/gitlab/gitlab.rb \
    /etc/gitlab/gitlab-secrets.json \
    "$LATEST_BACKUP"

log_and_notify "Archive created: $ARCHIVE_FILE"
printf "Archive created: $ARCHIVE_FILE"

#------------------ S3 ------------------
log_and_notify "Uploading to S3 ..."
printf "Uploadin to S3 ..."

s3cmd put "$ARCHIVE_FILE" s3://gitlab-1
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

ls -1t ${GITLAB_BACKUP_DIR}/*.tar | tail -n +1 | xargs -r rm -f
ls -1t ${TAR_DIR}/*.tar.gz | tail -n +2 | xargs -r rm -f

log_and_notify "Cleanup completed."
log_and_notify "GitLab backup finished successfully."
printf "Cleanup completed."
printf "GitLab backup finished successfully."

FIRST_HEREDOC
