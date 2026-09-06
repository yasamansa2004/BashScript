LOG_FILE="/var/log/daily-server-update.log"

{
    echo "========================================"
    echo "Update started: $(date)"
    echo "Hostname: $(hostname)"
    echo "========================================"

    echo
    echo "=== APT UPDATE ==="
    apt-get update

    echo
    echo "=== PACKAGE UPGRADE ==="
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

    echo
    echo "=== AUTOREMOVE ==="
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

    echo
    echo "=== AUTOCLEAN ==="
    apt-get autoclean -y

    echo
    echo "=== REBOOT CHECK ==="
    if [ -f /var/run/reboot-required ]; then
        echo "WARNING: Reboot required."
        if [ -f /var/run/reboot-required.pkgs ]; then
            echo "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs
        fi
    else
        echo "No reboot required."
    fi

    echo
    echo "Update finished: $(date)"
    echo "========================================"
    echo
} >> "$LOG_FILE" 2>&1
