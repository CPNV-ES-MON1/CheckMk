#!/bin/bash

# =============================================================================
# Title:        CheckMk Installation Script
# Description:  Automated installation script for CheckMk monitoring system
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-05-08
# Version:      1.0.0
#
# Requirements:
#   - Ubuntu/Debian-based system
#   - Root privileges
#   - Internet connection
#
# Usage:
#   sudo chmod +x install_checkmk.sh
#   sudo ./install_checkmk.sh
# =============================================================================

# Exit script on error
set -e

# Configuration variables
SITE_NAME="monitoring"
CHECKMK_VERSION="2.4.0"
EXPECTED_HASH="1cd25e1831c96871f67128cc87422d2a35521ce42409bad96ea1591acf3df1a4"

# Log messages with status
log() {
    local message=$1
    local status=$2  # "success", "error", "warning" or "info"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    case "$status" in
        "success")
            echo -e "[$timestamp] $message \033[32m[Success]\033[0m"
            ;;
        "error")
            echo -e "[$timestamp] $message \033[31m[Error]\033[0m"
            ;;
        "warning")
            echo -e "[$timestamp] $message \033[33m[Warning]\033[0m"
            ;;
        "info")
            echo -e "[$timestamp] $message \033[34m[Info]\033[0m"
            ;;
        *)
            echo -e "[$timestamp] $message"
            ;;
    esac
}

# Execute command and report status
execute_task() {
    local message=$1
    local command=$2
    local temp_output=$(mktemp)

    if eval "$command" > "$temp_output" 2>&1; then
        log "$message" "success"
    else
        local exit_code=$?
        log "$message failed (exit code: $exit_code)" "error"
        cat "$temp_output" >&2
        rm -f "$temp_output"
        exit 1
    fi
    rm -f "$temp_output"
}

# Verify package hash against expected value
verify_package() {
    local actual_hash=$1
    local expected_hash=$2

    if [ "$actual_hash" != "$expected_hash" ]; then
        log "Package integrity verification failed!" "error"
        echo "Expected: $expected_hash"
        echo "Actual:   $actual_hash"
        exit 1
    else
        log "Package integrity verified" "success"
    fi
}

# Check monitoring site status
check_site_status() {
    local site_name=$1
    local status_output=$(omd status "$site_name")

    if echo "$status_output" | grep -q "Overall state:.*running"; then
        log "Site $site_name status" "success"
    else
        log "Site $site_name may not be running correctly" "warning"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "This script must be run as root or with sudo privileges." "error"
        exit 1
    fi
}

# Check for root privileges
check_root

# Create directory for system information
mkdir -p BaseInstallationData && cd BaseInstallationData

# Collect system information
execute_task "Collecting installed packages" "dpkg --get-selections > packages.txt"
execute_task "Collecting open ports" "ss -tuln > ports.txt"
execute_task "Collecting running services" "systemctl list-units --type=service --state=running > services.txt"
execute_task "Collecting service statuses" "service --status-all > services-status.txt"
execute_task "Collecting hardware information" "lshw -short > hardware.txt"
execute_task "Collecting disk information" "lsblk > disks.txt"
execute_task "Backing up sources list" "cp /etc/apt/sources.list sources.list"

# Return to home directory
cd ~

# Update and upgrade packages
execute_task "Updating package repository" "apt update -qq"
execute_task "Upgrading packages" "DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq"

# Download CheckMk package
log "Downloading CheckMk package..." "info"
PACKAGE_FILE="check-mk-raw-${CHECKMK_VERSION}_0.jammy_amd64.deb"
DOWNLOAD_URL="https://download.checkmk.com/checkmk/${CHECKMK_VERSION}/${PACKAGE_FILE}"

if [ -f "$PACKAGE_FILE" ]; then
    log "Package file already exists" "info"
else
    if wget -q "$DOWNLOAD_URL" -O "$PACKAGE_FILE"; then
        log "Package download complete" "success"
    else
        WGET_EXIT_CODE=$?
        log "Package download failed" "error"
        echo "URL: $DOWNLOAD_URL"

        if [ $WGET_EXIT_CODE -eq 8 ]; then
            echo "Status: 404 Not Found"
            echo "Version $CHECKMK_VERSION may not exist. Check https://checkmk.com/download?platform=cmk&distribution=ubuntu&release=jammy"
        else
            echo "Exit code: $WGET_EXIT_CODE"
            echo "Try running: wget -v \"$DOWNLOAD_URL\" for more information"
        fi
        exit 1
    fi
fi

# Verify package integrity
ACTUAL_HASH=$(sha256sum "$PACKAGE_FILE" | awk '{print $1}')
verify_package "$ACTUAL_HASH" "$EXPECTED_HASH"

execute_task "Installing CheckMk package" "DEBIAN_FRONTEND=noninteractive apt install -y -q ./$PACKAGE_FILE"

# Verify installation
if command_exists omd; then
    INSTALLED_VERSION=$(omd version | grep -oP 'Version \K[^ ]+')
    log "CheckMk version $INSTALLED_VERSION installed" "success"
else
    log "CheckMk installation failed - omd command not found" "error"
    exit 1
fi

execute_task "Creating monitoring site '$SITE_NAME'" "omd create $SITE_NAME > site_creation.tmp"

# Extract password from output
SITE_PASSWORD=$(grep -oP 'cmkadmin with password: \K[^ ]+' site_creation.tmp)

if [ -n "$SITE_PASSWORD" ]; then
    log "Site credentials successfully extracted" "success"
else
    log "Could not extract site password" "warning"
fi

rm -f site_creation.tmp

execute_task "Starting monitoring site" "omd start $SITE_NAME"
check_site_status "$SITE_NAME"

# Get server IP for access information
SERVER_IP=$(hostname -I | awk '{print $1}')

log "═════════════════════════════════════════"
log "         Installation Summary            "
log "═════════════════════════════════════════"
log "CheckMk $INSTALLED_VERSION has been successfully installed"
log "Access the web interface: http://$SERVER_IP/$SITE_NAME/"
log "Credentials:"
log "  • Username: cmkadmin"
log "  • Password: $SITE_PASSWORD"
log "For CLI administration: omd su $SITE_NAME"
log "═════════════════════════════════════════"
