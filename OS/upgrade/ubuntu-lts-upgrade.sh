#!/usr/bin/env bash

set -Eeuo pipefail

LOG_FILE="/var/log/ubuntu-lts-upgrade.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo
echo "============================================================"
echo " Ubuntu Dynamic LTS Upgrade"
echo " Started: $(date)"
echo "============================================================"
echo

# ============================================================
# ROOT CHECK
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    echo "Example: sudo $0"
    exit 1
fi

# ============================================================
# LOAD OS INFORMATION
# ============================================================

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: /etc/os-release not found."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "ERROR: This script supports Ubuntu only."
    echo "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

CURRENT="${VERSION_ID}"

# ============================================================
# VALIDATE CURRENT VERSION
# ============================================================

if [[ ! "$CURRENT" =~ ^[0-9]+\.04$ ]]; then
    echo "ERROR: Current release is not an Ubuntu LTS release."
    echo "Current version: $CURRENT"
    echo
    echo "This script is designed for LTS → LTS upgrades."
    exit 1
fi

CURRENT_MAJOR="${CURRENT%%.*}"

# ============================================================
# CALCULATE NEXT LTS
# ============================================================

TARGET_MAJOR=$((CURRENT_MAJOR + 2))
EXPECTED_TARGET="${TARGET_MAJOR}.04"

echo "Current release : ${PRETTY_NAME}"
echo "Current version : ${CURRENT}"
echo "Expected target : Ubuntu ${EXPECTED_TARGET}"
echo

# ============================================================
# CHECK UPDATE-MANAGER
# ============================================================

if ! command -v do-release-upgrade >/dev/null 2>&1; then
    echo "do-release-upgrade is not installed."
    echo
    echo "Installing update-manager-core..."
    
    apt-get update
    apt-get install -y update-manager-core
fi

# ============================================================
# CHECK RELEASE-UPGRADE POLICY
# ============================================================

if [[ -f /etc/update-manager/release-upgrades ]]; then
    PROMPT=$(awk -F= '/^[[:space:]]*Prompt=/ {print $2}' \
        /etc/update-manager/release-upgrades | tail -n1)

    echo "Release upgrade policy: ${PROMPT:-not configured}"

    if [[ "${PROMPT:-}" != "lts" ]]; then
        echo
        echo "WARNING: /etc/update-manager/release-upgrades"
        echo "does not have Prompt=lts."
        echo
        echo "Recommended configuration:"
        echo
        echo "    Prompt=lts"
        echo
    fi
fi

# ============================================================
# CHECK FOR AVAILABLE RELEASE
# ============================================================

echo
echo "Checking Ubuntu release-upgrade availability..."
echo

CHECK_OUTPUT="$(do-release-upgrade -c 2>&1 || true)"

echo "$CHECK_OUTPUT"
echo

# ============================================================
# EXTRACT AVAILABLE VERSION
# ============================================================

AVAILABLE_VERSION="$(
    printf '%s\n' "$CHECK_OUTPUT" |
    grep -oE '[0-9]{2}\.[0-9]{2}' |
    head -n1 ||
    true
)"

# ============================================================
# NO RELEASE AVAILABLE
# ============================================================

if [[ -z "$AVAILABLE_VERSION" ]]; then
    echo "============================================================"
    echo " No supported LTS upgrade is currently available."
    echo "============================================================"
    echo
    echo "Current release : $CURRENT"
    echo "Expected target : $EXPECTED_TARGET"
    echo
    echo "The script will exit safely."
    echo
    exit 0
fi

# ============================================================
# VERIFY THAT AVAILABLE RELEASE IS THE EXPECTED NEXT LTS
# ============================================================

echo "Release upgrader reports:"
echo "Available release: $AVAILABLE_VERSION"
echo "Expected release : $EXPECTED_TARGET"
echo

if [[ "$AVAILABLE_VERSION" != "$EXPECTED_TARGET" ]]; then
    echo "ERROR: The available release is not the expected next LTS."
    echo
    echo "Current  : $CURRENT"
    echo "Expected : $EXPECTED_TARGET"
    echo "Available: $AVAILABLE_VERSION"
    echo
    echo "Upgrade will NOT be started automatically."
    exit 1
fi

# ============================================================
# FINAL CONFIRMATION
# ============================================================

echo "============================================================"
echo " Upgrade available"
echo "============================================================"
echo
echo "Current : Ubuntu $CURRENT"
echo "Target  : Ubuntu $EXPECTED_TARGET"
echo
echo "The system will now start the Ubuntu release upgrade."
echo
echo "IMPORTANT:"
echo " - Make sure you have a VMware snapshot."
echo " - Make sure backups are available."
echo " - SSH connection may be interrupted."
echo " - Third-party repositories may be disabled."
echo

read -r -p "Continue with Ubuntu ${EXPECTED_TARGET} upgrade? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo
    echo "Upgrade cancelled."
    exit 0
fi

# ============================================================
# START UPGRADE
# ============================================================

echo
echo "Starting upgrade..."
echo

exec do-release-upgrade
