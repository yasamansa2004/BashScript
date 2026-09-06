# Ubuntu Dynamic LTS Upgrade

A dynamic Ubuntu LTS upgrade procedure that determines the next LTS release automatically instead of hardcoding a maximum Ubuntu version.

## Overview

The upgrade logic follows the Ubuntu LTS release sequence:

```text
18.04 → 20.04 → 22.04 → 24.04 → 26.04 → 28.04 → ...
```

The target version is calculated dynamically from the currently installed Ubuntu version.

For example:

```text
Current: 18.04
Next LTS: 20.04
```

Later:

```text
Current: 24.04
Next LTS: 26.04
```

And in the future:

```text
Current: 26.04
Next LTS: 28.04
```

No hardcoded maximum version is required.

---

## Requirements

* Ubuntu LTS
* Root or `sudo` access
* `update-manager-core`
* Working APT repositories
* Sufficient free disk space
* Reliable network connectivity
* Console access or a reliable SSH session
* A verified backup
* VMware snapshot when running on VMware

Check the current Ubuntu version:

```bash
cat /etc/os-release
```

Example:

```text
PRETTY_NAME="Ubuntu 18.04.6 LTS"
VERSION_ID="18.04"
```

---

## Upgrade Strategy

The procedure performs the following steps:

```text
┌──────────────────────────────┐
│ Read /etc/os-release         │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Verify Ubuntu + LTS release  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Calculate next LTS           │
│ CURRENT_MAJOR + 2            │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ do-release-upgrade -c        │
│ Check actual availability    │
└──────────────┬───────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
     Available      Not available
        │             │
        ▼             ▼
   Confirmation       Exit
        │
        ▼
 do-release-upgrade
```

The calculated version is only an **expected target**.

The actual availability of the release is determined by Ubuntu's release upgrader.

---

## Dynamic Version Calculation

The current version is obtained from:

```bash
source /etc/os-release
CURRENT="$VERSION_ID"
```

For example:

```text
18.04
```

The major version can be extracted with:

```bash
CURRENT_MAJOR="${CURRENT%%.*}"
```

Result:

```text
18
```

The next LTS major version is then calculated:

```bash
TARGET_MAJOR=$((CURRENT_MAJOR + 2))
```

Result:

```text
20
```

Finally:

```bash
EXPECTED_TARGET="${TARGET_MAJOR}.04"
```

Result:

```text
20.04
```

Therefore:

```text
18.04 → 20.04
20.04 → 22.04
22.04 → 24.04
24.04 → 26.04
26.04 → 28.04
```

---

## Why There Is No Maximum Version

The upgrade logic intentionally does **not** contain something like:

```text
MAX_VERSION=26.04
```

A fixed maximum would make the automation obsolete when a new LTS is released.

For example, with:

```text
MAX_VERSION=26.04
```

the automation would eventually stop at:

```text
26.04
```

even after Ubuntu 28.04 became available.

Instead, the procedure calculates:

```text
current LTS + 2 years
```

and asks Ubuntu whether that release actually exists and is available for upgrade.

---

## Release Availability Check

The calculated target is not assumed to exist.

Ubuntu's release upgrader is queried with:

```bash
do-release-upgrade -c
```

This is important because the next calculated LTS may not have been released yet.

For example, if the server is running:

```text
26.04
```

the calculated target is:

```text
28.04
```

If Ubuntu 28.04 is not available yet, the procedure exits without attempting an upgrade.

Once 28.04 becomes available, the same automation can detect it without modifying the version logic.

---

## LTS-Only Design

This procedure is designed specifically for:

```text
LTS → LTS
```

It expects Ubuntu versions in the form:

```text
XX.04
```

Examples:

```text
18.04
20.04
22.04
24.04
26.04
```

It should not be used directly for interim releases such as:

```text
25.10
26.10
```

because the simple `+2` calculation represents the LTS-to-LTS path.

---

## Release Upgrade Policy

Check:

```bash
cat /etc/update-manager/release-upgrades
```

For an LTS-only upgrade strategy, the expected configuration is:

```text
Prompt=lts
```

This prevents the release upgrader from targeting interim Ubuntu releases.

---

## Pre-Upgrade Checks

Before starting an operating-system upgrade, verify the system is healthy.

### Check Ubuntu version

```bash
cat /etc/os-release
```

### Check disk space

```bash
df -h
```

### Check `/boot`

```bash
df -h /boot
```

### Check broken packages

```bash
dpkg --audit
```

The command should return no output.

### Check held packages

```bash
apt-mark showhold
```

Ideally, there should be no unexpected held packages.

### Check failed services

```bash
systemctl --failed
```

Expected:

```text
0 loaded units listed.
```

### Check pending upgrades

```bash
apt list --upgradable
```

### Update package information

```bash
apt update
```

---

## VMware Snapshot

When the server is running inside VMware, create a VMware snapshot before starting a major release upgrade.

Recommended workflow:

```text
VMware Snapshot
       │
       ▼
Pre-upgrade checks
       │
       ▼
Ubuntu release upgrade
       │
       ▼
Reboot
       │
       ▼
Post-upgrade validation
```

Do not rely on the snapshot as the only backup.

---

## Backup

Before upgrading a production server, verify that application and configuration backups are available.

For a GitLab Omnibus installation, important configuration files include:

```text
/etc/gitlab/gitlab.rb
/etc/gitlab/gitlab-secrets.json
```

A GitLab backup should also be created and verified before the OS upgrade.

The OS upgrade should not be considered a replacement for application-level backups.

---

## Docker Considerations

If Docker is installed, check:

```bash
docker version
```

Check containers:

```bash
docker ps -a
```

Check Docker service:

```bash
systemctl status docker --no-pager
```

Ubuntu 26.04 removes support for cgroup v1.

Therefore, Docker/container workloads should be checked for cgroup compatibility before upgrading to Ubuntu 26.04 or later.

Check the current cgroup configuration:

```bash
stat -fc %T /sys/fs/cgroup
```

Also check:

```bash
docker info
```

and inspect the `Cgroup Version` field.

---

## Third-Party APT Repositories

Ubuntu release upgrades can disable or require changes to third-party repositories.

Check:

```bash
ls -la /etc/apt/sources.list.d/
```

Review:

```text
/etc/apt/sources.list
/etc/apt/sources.list.d/
```

Common examples include:

* Docker
* GitLab
* Kubernetes
* HashiCorp
* PostgreSQL
* Nexus
* Monitoring repositories

Third-party repositories should be verified for compatibility with the target Ubuntu release.

---

## GitLab Considerations

If GitLab Omnibus is installed, treat the GitLab upgrade separately from the Ubuntu operating-system upgrade.

Before the OS upgrade:

1. Create a GitLab backup.
2. Back up `/etc/gitlab/gitlab.rb`.
3. Back up `/etc/gitlab/gitlab-secrets.json`.
4. Verify GitLab services are healthy.
5. Verify GitLab is accessible.
6. Confirm the GitLab version is compatible with the target OS.
7. Perform GitLab application upgrades separately according to GitLab's supported upgrade path.

Avoid combining a large GitLab version jump with an operating-system release upgrade unless compatibility and rollback procedures have been verified.

---

## Upgrade Command

The actual Ubuntu upgrade is performed by:

```bash
do-release-upgrade
```

Before executing it, the procedure should verify:

1. Current OS is Ubuntu.
2. Current release is LTS.
3. Next LTS is calculated.
4. Ubuntu reports that the expected release is available.
5. Required backups exist.
6. The administrator confirms the upgrade.

---

## Example: Current Ubuntu 18.04

The system reports:

```text
VERSION_ID="18.04"
```

The procedure calculates:

```text
Current major: 18
Target major : 20
Target LTS   : 20.04
```

Ubuntu is then queried:

```bash
do-release-upgrade -c
```

If Ubuntu reports 20.04 as available, the upgrade can proceed.

---

## Example: Current Ubuntu 24.04

The procedure calculates:

```text
Current major: 24
Target major : 26
Target LTS   : 26.04
```

The same upgrade logic is used:

```text
24.04 → 26.04
```

No change to the automation is required.

---

## Example: Future Ubuntu 28.04

After Ubuntu 28.04 is released, a server running 26.04 will automatically calculate:

```text
Current: 26.04
Target : 28.04
```

The automation does not need to be modified.

This is the primary reason for avoiding a hardcoded maximum release.

---

## Safe Failure Behavior

The procedure should fail safely when:

* The operating system is not Ubuntu.
* The current release is not LTS.
* `do-release-upgrade` is unavailable.
* The next release is not currently available.
* Ubuntu reports an unexpected release.
* Required pre-upgrade checks fail.

A missing future release should **not** be treated as an error requiring script modification.

For example:

```text
Current release : 26.04
Expected target : 28.04

No supported LTS upgrade is currently available.

Exit safely.
```

When 28.04 becomes available, the same procedure can be executed again.

---

## Post-Upgrade Validation

After the upgrade and reboot, verify:

### OS

```bash
cat /etc/os-release
```

### Kernel

```bash
uname -r
```

### Failed services

```bash
systemctl --failed
```

### Disk

```bash
df -h
```

### APT

```bash
apt update
```

### Packages

```bash
dpkg --audit
```

### Docker

```bash
systemctl status docker --no-pager
docker ps -a
docker info
```

### GitLab

```bash
sudo gitlab-ctl status
```

Then verify the GitLab web interface and repositories.

---

## Recommended Production Workflow

For a production server:

```text
1. Create VMware snapshot
        ↓
2. Verify backups
        ↓
3. Check GitLab health
        ↓
4. Check Docker health
        ↓
5. Check disk /boot space
        ↓
6. Check APT repositories
        ↓
7. Check cgroup configuration
        ↓
8. Calculate next LTS dynamically
        ↓
9. Run do-release-upgrade -c
        ↓
10. Confirm expected LTS is available
        ↓
11. Start do-release-upgrade
        ↓
12. Reboot
        ↓
13. Validate OS
        ↓
14. Validate GitLab
        ↓
15. Validate Docker
        ↓
16. Validate applications
```

---

## Design Principle

The key principle of this automation is:

> **Calculate the next LTS dynamically, but let Ubuntu determine whether that release is actually available.**

This avoids both problems:

### Hardcoded approach

```text
18.04 → 20.04
20.04 → 22.04
22.04 → 24.04
24.04 → 26.04
```

Requires modifying the automation when a new LTS is released.

### Dynamic approach

```text
CURRENT LTS
     │
     ├── +2 years
     │
     ▼
EXPECTED NEXT LTS
     │
     ▼
Ubuntu release upgrader
     │
     ├── Available → Upgrade
     │
     └── Not available → Exit safely
```

This approach remains usable for future Ubuntu LTS releases without maintaining a version-specific `case` statement or maximum-version variable.


## Installing and Running the Upgrade Script

Save the upgrade script on the server:

```bash
sudo nano /usr/local/sbin/ubuntu-lts-upgrade
```

Paste the upgrade script into the file and save it.

### Make the Script Executable

After saving the file, make it executable:

```bash
sudo chmod +x /usr/local/sbin/ubuntu-lts-upgrade
```

Verify the permissions:

```bash
ls -l /usr/local/sbin/ubuntu-lts-upgrade
```

Expected output should contain:

```text
-rwxr-xr-x
```

### Run the Script

Run the script with `sudo`:

```bash
sudo /usr/local/sbin/ubuntu-lts-upgrade
```

Because the script is located in `/usr/local/sbin`, you can also run it directly as root:

```bash
ubuntu-lts-upgrade
```

However, using the full path is recommended:

```bash
sudo /usr/local/sbin/ubuntu-lts-upgrade
```

### Run the Script with Bash Explicitly

If the executable permission has not been set, the script can still be executed using Bash:

```bash
sudo bash /usr/local/sbin/ubuntu-lts-upgrade
```

This does not require the executable bit.

### Check the Script Before Running

It is recommended to perform a syntax check before executing the upgrade:

```bash
sudo bash -n /usr/local/sbin/ubuntu-lts-upgrade
```

If there is no output, the Bash syntax is valid.

### Check the Script File

You can inspect the script with:

```bash
sudo less /usr/local/sbin/ubuntu-lts-upgrade
```

or:

```bash
sudo cat /usr/local/sbin/ubuntu-lts-upgrade
```

### Upgrade Log

The script writes its output to:

```text
/var/log/ubuntu-lts-upgrade.log
```

You can monitor the log with:

```bash
sudo tail -f /var/log/ubuntu-lts-upgrade.log
```

Or review the complete log:

```bash
sudo less /var/log/ubuntu-lts-upgrade.log
```

### Recommended Execution Sequence

For a production server, use:

```bash
# 1. Save the script
sudo nano /usr/local/sbin/ubuntu-lts-upgrade

# 2. Make it executable
sudo chmod +x /usr/local/sbin/ubuntu-lts-upgrade

# 3. Check Bash syntax
sudo bash -n /usr/local/sbin/ubuntu-lts-upgrade

# 4. Review the script
sudo less /usr/local/sbin/ubuntu-lts-upgrade

# 5. Run the upgrade process
sudo /usr/local/sbin/ubuntu-lts-upgrade
```

The script will first check the current Ubuntu release and calculate the expected next LTS. It will then use `do-release-upgrade -c` to verify that the target release is actually available.

The script does **not** immediately start the upgrade without confirmation.

---

## Important: Do Not Run the Script Blindly

Before executing:

```bash
sudo /usr/local/sbin/ubuntu-lts-upgrade
```

make sure the production server has:

* A verified backup
* A VMware snapshot
* Sufficient free disk space
* Sufficient `/boot` space
* Healthy GitLab services
* Healthy Docker services
* No unexpected failed systemd services
* No broken packages
* No unexpected held packages
* Verified third-party APT repositories
* A reliable way to access the server if the SSH connection is interrupted

The script automates the **release detection and upgrade process**, but it does not replace the pre-upgrade validation and rollback plan.
