#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

LOG_FILE="/var/log/move-in.log"
> "$LOG_FILE" # Clear log file

# Function to log errors
log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Function to copy log files to desktop
copy_logs_to_desktop() {
    LOG_SOURCE="/var/log/move-in.log"
    DESTINATION="$HOME/Desktop/move-in.log"

    if cp "$LOG_SOURCE" "$DESTINATION"; then
        echo "Log file copied to Desktop successfully."
    else
        log_error "Failed to copy log file to Desktop."
    fi

    # Copy other relevant log files (add any additional log files here)
    # Example:
    # cp /var/log/another-log-file.log "$HOME/Desktop/"
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

# Update the system
if confirm "Do you want to update system packages?"; then
    echo "Updating system packages..."
    apt update && apt upgrade -y || log_error "Failed to update system packages."
fi

# Install dependencies
if confirm "Do you want to install necessary must-haves?"; then
    echo "Installing must-haves..."
    apt install -y curl wget perl mutt || log_error "Failed to install must-haves."
fi

# Install ProtonVPN
if confirm "Do you want to install ProtonVPN?"; then
    echo "Installing ProtonVPN..."
    git clone https://github.com/Spaghettio73/proton
    sudo cp -R /home/main/proton/* /home/main/.config/*
    sudo wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.4_all.deb || log_error "Failed to wget protonvpn .deb file."
    sudo dpkg -i ./protonvpn-stable-release_1.0.4_all.deb && sudo apt update || log_error "Failed to dpkg the .deb."
    sudo apt install proton-vpn-gnome-desktop -y || log_error "Failed to install ProtonVPN."

    # Launch ProtonVPN
    echo "Launching ProtonVPN..."
    if ! protonvpn-app.desktop &; then
        log_error "Failed to launch ProtonVPN. Please check your installation."
        exit 1
    fi

    # Optionally, wait for the app to start completely
    sleep 5  # Adjust time as necessary

    # Check if ProtonVPN is running
    if ! pgrep -x "protonvpn" > /dev/null; then
        log_error "ProtonVPN did not start successfully."
        exit 1
    fi

    echo "ProtonVPN launched successfully."
    # Optionally, add commands here to connect or configure ProtonVPN
fi

# Install BiglyBT 
if confirm "Do you want to install BiglyBT?"; then
    echo "Installing BiglyBT..."
    git clone https://github.com/Spaghettio73/biglybt
    sudo sh biglybt/BiglyBT_Installer.sh || log_error "Failed to install BiglyBT."
    sudo apt update && sudo apt upgrade -y || log_error "Failed to update and or upgrade."
fi

# Copy logs to desktop
copy_logs_to_desktop

echo "Installation script completed. Check $LOG_FILE for any errors."
