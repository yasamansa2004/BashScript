1. Create the update script
sudo nano /usr/local/sbin/daily-server-update.sh

Use:

#!/bin/bash

LOG_FILE="/var/log/daily-server-update.log"

{
    echo "========================================"
    echo "Update started: $(date)"
    echo "========================================"

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
    apt-get autoclean -y

    if [ -f /var/run/reboot-required ]; then
        echo "WARNING: Reboot required."
    else
        echo "No reboot required."
    fi

    echo "Update finished: $(date)"
    echo
} >> "$LOG_FILE" 2>&1

Make it executable:

sudo chmod +x /usr/local/sbin/daily-server-update.sh
2. Test it
sudo /usr/local/sbin/daily-server-update.sh

Check the log:

sudo tail -100 /var/log/daily-server-update.log
3. Add cronjob

Open root's crontab:

sudo crontab -e

Add:

0 4 * * * /usr/local/sbin/daily-server-update.sh

This means:

Every day at 04:00

Verify:

sudo crontab -l

You should see:

0 4 * * * /usr/local/sbin/daily-server-update.sh
4. Make sure cron is running
sudo systemctl status cron

If it's not running:

sudo systemctl enable --now cron
Optional: keep only 30 days of logs

Add this to the script:

find /var/log/daily-server-update.log -mtime +30 -delete

But because that's a single continuously appended file, I'd actually recommend using logrotate instead if this server will run for a long time.

find /var/log/daily-server-update.log -mtime +30 -delete

do it

Yep. For a single log file, use logrotate instead of find. It will rotate the log daily and keep 30 old copies.

1. Create logrotate config
sudo nano /etc/logrotate.d/daily-server-update

Put:

/var/log/daily-server-update.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
2. Test the configuration
sudo logrotate -d /etc/logrotate.d/daily-server-update

-d is a dry run; it won't modify anything.

3. Force a rotation to verify
sudo logrotate -f /etc/logrotate.d/daily-server-update

Check:

ls -lh /var/log/daily-server-update*

You should eventually have:

daily-server-update.log
daily-server-update.log.1
daily-server-update.log.2.gz
daily-server-update.log.3.gz
...
4. Your cronjob stays simple
sudo crontab -e
0 4 * * * /usr/local/sbin/daily-server-update.sh

So the final setup is:

04:00 every day
      │
      ▼
daily-server-update.sh
      │
      ├── apt-get update
      ├── apt-get upgrade -y
      ├── apt-get autoremove -y
      └── apt-get autoclean
               │
               ▼
/var/log/daily-server-update.log
               │
               ▼
          logrotate
               │
               └── keeps 30 days

Don't add the find ... -delete command to the script; logrotate now handles retention properly.

Yesterday 5:15 PM
oot@Berooziran-ST:/srv/scripts# sudo logrotate -f /etc/logrotate.d/daily-server-update
error: skipping "/var/log/daily-server-update.log" because parent directory has insecure permissions (It's world writable or writable by group which is not "root") Set "su" directive in config file to tell logrotate which user/group should be used for rotation.
root@Berooziran-ST:/srv/scripts# 

The error means /var/log itself has permissions that logrotate considers insecure. Since you're running the rotation as root, the cleanest fix is to explicitly tell logrotate to rotate the file as root:root.

Edit:

sudo nano /etc/logrotate.d/daily-server-update

Change it to:

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

Then make sure the log file itself is owned correctly:

sudo chown root:root /var/log/daily-server-update.log
sudo chmod 640 /var/log/daily-server-update.log

Now test:

sudo logrotate -f /etc/logrotate.d/daily-server-update

Check:

ls -lah /var/log/daily-server-update*

You should get something like:

-rw-r----- 1 root root   ... daily-server-update.log
-rw-r----- 1 root root   ... daily-server-update.log.1
Also check /var/log permissions

Run:

ls -ld /var/log

Normally you should see something similar to:

drwxr-xr-x root root /var/log

If you see something like:

drwxrwxrwx

or the group is writable, don't immediately chmod it because something on your server may intentionally have modified /var/log.

Show me the output of:

ls -ld /var/log
ls -l /var/log/daily-server-update.log

and I can tell you whether the su root root fix is enough or whether /var/log itself needs correction.
