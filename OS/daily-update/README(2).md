# Daily Server Update

Automated daily Ubuntu server package updates using **cron**, with persistent logging and **logrotate**.

## What this setup does

Every day at **04:00**, root's cron executes:

```text
/usr/local/sbin/daily-server-update.sh
```

The script:

1. Runs `apt-get update`
2. Runs `apt-get upgrade -y`
3. Runs `apt-get autoremove -y`
4. Runs `apt-get autoclean -y`
5. Checks whether the server requires a reboot
6. Logs all output to:

```text
/var/log/daily-server-update.log
```

Logrotate then rotates the log and keeps **30 rotated logs**.

> **Important:** The script does **not** automatically reboot the server.

---

# 1. Required Files

This setup uses two configuration files plus the update script:

```text
/usr/local/sbin/daily-server-update.sh
/etc/logrotate.d/daily-server-update
```

The cron schedule is stored in root's crontab:

```bash
sudo crontab -l
```

The update log is:

```text
/var/log/daily-server-update.log
```

---

# 2. Install the Update Script

Copy the provided script to:

```bash
sudo cp daily-server-update.sh /usr/local/sbin/daily-server-update.sh
```

Make it executable:

```bash
sudo chmod +x /usr/local/sbin/daily-server-update.sh
```

Verify:

```bash
ls -l /usr/local/sbin/daily-server-update.sh
```

Expected permissions should include executable bits, for example:

```text
-rwxr-xr-x root root ... /usr/local/sbin/daily-server-update.sh
```

---

# 3. Update Script Behavior

The script writes its output to:

```text
/var/log/daily-server-update.log
```

The log contains:

- Start time
- Hostname
- APT update output
- Package upgrade output
- Autoremove output
- Autoclean output
- Reboot-required status
- Packages that requested a reboot, when available
- Finish time

The script is intended to run as root.

---

# 4. Test the Update Script

Before relying on cron, execute it manually:

```bash
sudo /usr/local/sbin/daily-server-update.sh
```

Check the result:

```bash
sudo tail -100 /var/log/daily-server-update.log
```

Follow the log while it runs:

```bash
sudo tail -f /var/log/daily-server-update.log
```

If there are APT errors, investigate those before enabling unattended daily execution.

---

# 5. Cron Job

Open root's crontab:

```bash
sudo crontab -e
```

Add:

```cron
0 4 * * * /usr/local/sbin/daily-server-update.sh
```

This means:

```text
Minute:  0
Hour:    4
Day:     Every day
Month:   Every month
Weekday: Every day
```

Therefore:

```text
Every day at 04:00
```

Verify the entry:

```bash
sudo crontab -l
```

Expected:

```cron
0 4 * * * /usr/local/sbin/daily-server-update.sh
```

---

# 6. Verify Cron

Check the cron service:

```bash
sudo systemctl status cron
```

If it is not running:

```bash
sudo systemctl enable --now cron
```

Verify:

```bash
systemctl is-active cron
```

Expected:

```text
active
```

Check cron activity:

```bash
sudo journalctl -u cron --since "today"
```

On systems that log cron activity to syslog:

```bash
sudo grep CRON /var/log/syslog
```

---

# 7. Log File

The update script uses:

```text
/var/log/daily-server-update.log
```

Check it:

```bash
sudo ls -lh /var/log/daily-server-update.log
```

View the latest entries:

```bash
sudo tail -100 /var/log/daily-server-update.log
```

Follow it in real time:

```bash
sudo tail -f /var/log/daily-server-update.log
```

The script itself does not delete old logs.

**Log retention is handled by logrotate.**

---

# 8. Logrotate Configuration

Create:

```bash
sudo nano /etc/logrotate.d/daily-server-update
```

Use:

```conf
/var/log/daily-server-update.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su root root
}
```

## Logrotate options

| Option | Purpose |
|---|---|
| `daily` | Rotate the log daily |
| `rotate 30` | Keep 30 rotated logs |
| `compress` | Compress old rotated logs |
| `delaycompress` | Compress the previous rotation on the following cycle |
| `missingok` | Don't fail if the log file doesn't exist |
| `notifempty` | Don't rotate an empty log |
| `copytruncate` | Copy the current log and truncate it in place |
| `su root root` | Perform rotation as `root:root` |

The `su root root` directive is important on systems where logrotate reports:

```text
error: skipping "/var/log/daily-server-update.log" because parent directory has insecure permissions
```

---

# 9. Log File Permissions

Make sure the log is owned by root:

```bash
sudo chown root:root /var/log/daily-server-update.log
```

Set permissions:

```bash
sudo chmod 640 /var/log/daily-server-update.log
```

Verify:

```bash
ls -l /var/log/daily-server-update.log
```

Expected:

```text
-rw-r----- 1 root root ... /var/log/daily-server-update.log
```

---

# 10. Check `/var/log` Permissions

Check the parent directory:

```bash
ls -ld /var/log
```

Normally it should look similar to:

```text
drwxr-xr-x root root /var/log
```

If `/var/log` is group-writable or world-writable, investigate why before changing it.

Do not blindly change `/var/log` permissions on a production server.

The logrotate configuration already includes:

```conf
su root root
```

which allows logrotate to explicitly perform the rotation as root.

---

# 11. Test Logrotate

First perform a dry run:

```bash
sudo logrotate -d /etc/logrotate.d/daily-server-update
```

The `-d` option does not perform the rotation.

Look for errors.

Then force a rotation:

```bash
sudo logrotate -f /etc/logrotate.d/daily-server-update
```

Check the resulting files:

```bash
ls -lah /var/log/daily-server-update*
```

Expected files will look similar to:

```text
daily-server-update.log
daily-server-update.log.1
daily-server-update.log.2.gz
daily-server-update.log.3.gz
...
```

The exact files present depend on how many rotations have occurred.

---

# 12. Why `find ... -delete` Is Not Used

Do not add this to the update script:

```bash
find /var/log/daily-server-update.log -mtime +30 -delete
```

That command is not appropriate for this log-rotation design because the update script continuously appends to one active log file.

Instead, logrotate manages:

- Rotation
- Compression
- Retention
- Old log removal

The configuration:

```conf
rotate 30
```

keeps 30 rotated copies.

---

# 13. Reboot Detection

The update script checks:

```text
/var/run/reboot-required
```

If this file exists, the log reports:

```text
WARNING: Reboot required.
```

You can manually check:

```bash
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required"
else
    echo "No reboot required"
fi
```

If available, check which packages requested the reboot:

```bash
cat /var/run/reboot-required.pkgs 2>/dev/null
```

## Automatic reboot

This setup intentionally does **not** reboot the server automatically.

If a kernel or critical system library update requires a reboot, the administrator should schedule the reboot during an appropriate maintenance window.

---

# 14. Daily Execution Flow

```text
                         04:00
                           │
                           ▼
                    Root Cron Job
                           │
                           ▼
       /usr/local/sbin/daily-server-update.sh
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
      apt-get update  apt-get upgrade  autoremove
                                          │
                                          ▼
                                      autoclean
                           │
                           ▼
            /var/log/daily-server-update.log
                           │
                           ▼
                       logrotate
                           │
                           ▼
                  30 rotated logs
```

---

# 15. Complete Installation

If starting from scratch, the basic sequence is:

### Install script

```bash
sudo cp daily-server-update.sh /usr/local/sbin/daily-server-update.sh
sudo chmod +x /usr/local/sbin/daily-server-update.sh
```

### Create the log

The script will create the log automatically when it runs.

You can also create it explicitly:

```bash
sudo touch /var/log/daily-server-update.log
sudo chown root:root /var/log/daily-server-update.log
sudo chmod 640 /var/log/daily-server-update.log
```

### Create logrotate configuration

```bash
sudo nano /etc/logrotate.d/daily-server-update
```

Add:

```conf
/var/log/daily-server-update.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su root root
}
```

### Test the script

```bash
sudo /usr/local/sbin/daily-server-update.sh
```

### Test logrotate

```bash
sudo logrotate -d /etc/logrotate.d/daily-server-update
```

### Configure cron

```bash
sudo crontab -e
```

Add:

```cron
0 4 * * * /usr/local/sbin/daily-server-update.sh
```

### Verify

```bash
sudo crontab -l
sudo systemctl is-active cron
sudo tail -100 /var/log/daily-server-update.log
```

---

# 16. Full Verification Checklist

Run:

```bash
sudo test -x /usr/local/sbin/daily-server-update.sh \
    && echo "Update script: OK" \
    || echo "Update script: ERROR"
```

```bash
sudo crontab -l
```

```bash
sudo systemctl is-active cron
```

```bash
sudo logrotate -d /etc/logrotate.d/daily-server-update
```

```bash
ls -lah /var/log/daily-server-update*
```

```bash
sudo tail -50 /var/log/daily-server-update.log
```

Check reboot status:

```bash
if [ -f /var/run/reboot-required ]; then
    echo "REBOOT REQUIRED"
else
    echo "NO REBOOT REQUIRED"
fi
```

---

# 17. Production Considerations

This setup is intended for routine Ubuntu package patching.

It is **not** an automatic Ubuntu release-upgrade mechanism.

Do not add commands such as:

```bash
do-release-upgrade
```

to the daily cron job.

Also avoid blindly replacing:

```bash
apt-get upgrade -y
```

with:

```bash
apt-get dist-upgrade -y
```

for production infrastructure unless you have explicitly reviewed the consequences.

For servers running services such as:

- Docker
- PostgreSQL
- Nginx
- Kubernetes
- GitLab Runner
- Monitoring systems
- Other production workloads

review major package changes and reboot requirements before performing maintenance.

---

# 18. Troubleshooting

## Script does not execute

Check:

```bash
ls -l /usr/local/sbin/daily-server-update.sh
```

Make executable:

```bash
sudo chmod +x /usr/local/sbin/daily-server-update.sh
```

Run manually:

```bash
sudo /usr/local/sbin/daily-server-update.sh
```

---

## Cron does not execute

Check:

```bash
sudo systemctl status cron
```

Check the crontab:

```bash
sudo crontab -l
```

Check cron logs:

```bash
sudo journalctl -u cron
```

or:

```bash
sudo grep CRON /var/log/syslog
```

---

## Logrotate reports insecure permissions

If you see:

```text
parent directory has insecure permissions
```

make sure the configuration contains:

```conf
su root root
```

Then verify:

```bash
ls -ld /var/log
ls -l /var/log/daily-server-update.log
```

Make sure the log itself is:

```bash
sudo chown root:root /var/log/daily-server-update.log
sudo chmod 640 /var/log/daily-server-update.log
```

Test again:

```bash
sudo logrotate -f /etc/logrotate.d/daily-server-update
```

---

# 19. Security Notes

The update script runs as **root** because APT package operations require elevated privileges.

Therefore:

```text
/usr/local/sbin/daily-server-update.sh
```

should not be writable by unprivileged users.

Verify:

```bash
ls -l /usr/local/sbin/daily-server-update.sh
```

The script should be owned by root:

```bash
sudo chown root:root /usr/local/sbin/daily-server-update.sh
```

Recommended permissions:

```bash
sudo chmod 755 /usr/local/sbin/daily-server-update.sh
```

Do not place the script in a directory writable by normal users.

---

# 20. Final Configuration

The final configuration is:

```text
/usr/local/sbin/daily-server-update.sh
        │
        │ executed by
        ▼
root crontab
        │
        │ 0 4 * * *
        ▼
Daily package maintenance
        │
        ├── apt-get update
        ├── apt-get upgrade -y
        ├── apt-get autoremove -y
        └── apt-get autoclean -y
        │
        ▼
/var/log/daily-server-update.log
        │
        ▼
/etc/logrotate.d/daily-server-update
        │
        ├── daily rotation
        ├── compression
        └── 30 rotated logs
```

## Quick Commands

### Run update now

```bash
sudo /usr/local/sbin/daily-server-update.sh
```

### View update log

```bash
sudo tail -100 /var/log/daily-server-update.log
```

### View cron configuration

```bash
sudo crontab -l
```

### Check cron

```bash
sudo systemctl status cron
```

### Test logrotate

```bash
sudo logrotate -d /etc/logrotate.d/daily-server-update
```

### Force log rotation

```bash
sudo logrotate -f /etc/logrotate.d/daily-server-update
```

### List logs

```bash
ls -lah /var/log/daily-server-update*
```

### Check reboot requirement

```bash
[ -f /var/run/reboot-required ] && echo "REBOOT REQUIRED" || echo "NO REBOOT REQUIRED"
```
