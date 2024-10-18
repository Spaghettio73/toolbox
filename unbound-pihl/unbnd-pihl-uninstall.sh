#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

LOG_FILE="/var/log/pihole_unbound_uninstall.log"
> "$LOG_FILE" # Clear log file

# Function to log errors
log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Check for appropriate elevated privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Function to confirm with yes/no
confirm() {
    while true; do
        read -rp "$1 (y/n): " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Uninstall Pi-hole
if confirm "Do you want to uninstall Pi-hole?"; then
    echo "Uninstalling Pi-hole..."
    pihole uninstall || log_error "Failed to uninstall Pi-hole."
fi

# Stop and disable Unbound
if confirm "Do you want to stop and disable Unbound?"; then
    echo "Stopping and disabling Unbound..."
    systemctl stop unbound || log_error "Failed to stop Unbound."
    systemctl disable unbound || log_error "Failed to disable Unbound."
fi

# Uninstall Unbound
if confirm "Do you want to uninstall Unbound?"; then
    echo "Uninstalling Unbound..."
    apt purge -y unbound unbound-host || log_error "Failed to uninstall Unbound."
fi

# Auto-remove dependencies
if confirm "Do you want to auto-remove unused dependencies?"; then
    echo "Removing unused dependencies..."
    apt autoremove -y || log_error "Failed to remove unused dependencies."
fi

# Cleanup configuration files
if confirm "Do you want to remove configuration files?"; then
    echo "Cleaning up configuration files..."
    rm -rf /etc/unbound || log_error "Failed to remove /etc/unbound."
    rm -rf /etc/pihole || log_error "Failed to remove /etc/pihole."
fi

# Remove update script
if confirm "Do you want to remove the update script?"; then
    echo "Removing the update script..."
    rm -f /usr/local/bin/update_pihole || log_error "Failed to remove update script."
fi

echo "Uninstallation script completed. Check $LOG_FILE for any errors."
