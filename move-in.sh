#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

LOG_FILE="/var/log/move-in.log"
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

# Update the system
if confirm "Do you want to update system packages?"; then
    echo "Updating system packages..."
    apt update && apt upgrade -y || log_error "Failed to update system packages."
fi

# Install dependencies
if confirm "Do you want to install necessary must-haves?"; then
    echo "Installing must-haves..."
    apt install -y curl wget perl mutt  || log_error "Failed to install must-haves."
fi


# Install ProtonVPN
if confirm "Do you want to you want to install ProtonVPN?"; then
    echo "Installing ProtonVPN..."
        git clone https://github.com/Spaghettio73/proton
        sudo cp -R /home/main/proton/* /home/main/.config/*
        sudo wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.4_all.deb || log_error "Failed to wget protonvpn .deb file."
        sudo dpkg -i ./protonvpn-stable-release_1.0.4_all.deb && sudo apt update || log_error "Failed to dpkg the .deb."
        sudo apt install proton-vpn-gnome-desktop -y || log_error "Failed to install ProtonVPN."
        sudo apt update && sudo apt upgrade -y || log_error "Failed to update and or upgrade."
fi

# Install BiglyBT 
if confirm "Do you want to you want to install BiglyBT?"; then
    echo "Installing BiglyBT..."
        git clone https://github.com/Spaghettio73/biglybt
        sudo cp -R /home/main/biglybt/* /home/main/*
        sudo curl -O https://files.biglybt.com/installer/BiglyBT_Installer.sh || log_error "Failed to curl BiglyBT install file."
        sudo sh ./BigltBT_Installer.sh || log_error "Failed to install BiglyBT."
        sudo apt update && sudo apt upgrade -y || log_error "Failed to update and or upgrade."
fi

echo "Installation script completed. Check $LOG_FILE for any errors."



