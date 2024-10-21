#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

LOG_FILE="/var/log/move-in.log"
VERBOSE_LOG_DIR="$HOME/Desktop/Install_Logs"
PROTON_LOG="$VERBOSE_LOG_DIR/protonvpn.log"
BIGLYBT_LOG="$VERBOSE_LOG_DIR/biglybt.log"

# Ensure the log file is writable
mkdir -p /var/log
touch "$LOG_FILE"
> "$LOG_FILE" # Clear log file

# Create verbose log directory
mkdir -p "$VERBOSE_LOG_DIR"

# Function to log errors
log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Check for appropriate elevated privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo." | tee -a "$LOG_FILE"
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

# Function to run commands and log errors
run_command() {
    "$@" >> "$LOG_FILE" 2>&1 || log_error "Command failed: $*"
}

# Update the system
if confirm "Do you want to update system packages?"; then
    echo "Updating system packages..."
    run_command apt update
    run_command apt upgrade -y
fi

# Install dependencies
if confirm "Do you want to install necessary must-haves?"; then
    echo "Installing must-haves..."
    run_command apt install -y curl wget perl mutt
fi

# Install ProtonVPN
if confirm "Do you want to install ProtonVPN?"; then
    echo "Installing ProtonVPN..."
    run_command git clone https://github.com/Spaghettio73/proton
    run_command cp -R /home/main/proton/* /home/main/.config/*
    run_command wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.4_all.deb
    run_command dpkg -i ./protonvpn-stable-release_1.0.4_all.deb
    run_command apt update
    run_command apt install proton-vpn-gnome-desktop -y
    
    # Start ProtonVPN and check status
    run_command protonvpn-cli connect --fastest
    sleep 5  # Wait for the connection to stabilize
    STATUS=$(protonvpn-cli status)
    if [[ $STATUS == *"Connected"* ]]; then
        echo "ProtonVPN is connected." >> "$LOG_FILE"
    else
        log_error "ProtonVPN failed to connect. Status: $STATUS"
    fi
fi

# Install BiglyBT
if confirm "Do you want to install BiglyBT?"; then
    echo "Installing BiglyBT..."
    run_command git clone https://github.com/Spaghettio73/biglybt
    run_command sh biglybt/BiglyBT_Installer.sh
    
    # Check installation
    if ! command -v biglybt &> /dev/null; then
        log_error "BiglyBT installation failed."
    else
        echo "BiglyBT installed successfully." >> "$LOG_FILE"
    fi
fi

echo "Installation script completed. Check $LOG_FILE for any errors."
