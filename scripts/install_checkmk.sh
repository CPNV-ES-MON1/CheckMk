#!/bin/bash

# =============================================================================
# Title:        CheckMk Installation Script
# Description:  Automated installation and configuration of CheckMk monitoring
#               Creates site, folders, and adds hosts from config.json
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2025-05-28
# Version:      1.1.0
#
# Requirements:
#   - Ubuntu/Debian-based system
#   - Root privileges (run with sudo)
#   - Internet connection
#   - config.json file in same directory as script
#
# Usage:        sudo ./install_checkmk.sh [--debug]
# =============================================================================

# Exit script on error
set -e

# Debug mode flag
DEBUG_MODE=false
if [[ "$*" == *"--debug"* ]]; then
    DEBUG_MODE=true
fi

# Path variables
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
BASE_DIR=$(pwd)

# Variables populated from config files
SITE_NAME=""
CHECKMK_VERSION=""
EXPECTED_HASH=""
FOLDERS=()
PACKAGE_FILE=""
DOWNLOAD_URL=""
SITE_PASSWORD=""

# Default checkmk admin username
API_USERNAME="cmkadmin"

# Log messages with status
log() {
    local message=$1
    local status=$2 # "success", "error", "warning", "info", "debug"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    if [ "$status" = "debug" ] && [ "$DEBUG_MODE" = false ]; then
        return
    fi

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
    "debug")
        echo -e "[$timestamp] $message \033[35m[Debug]\033[0m"
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
    local long_operation=$3
    local temp_output=$(mktemp)

    if [ "$long_operation" = "true" ]; then
        log "$message (this might take several minutes)..." "info"
    else
        log "$message" "info"
    fi

    if eval "$command" >"$temp_output" 2>&1; then
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "This script must be run as root or with sudo privileges." "error"
        exit 1
    fi
}

# Install required dependencies
install_dependencies() {
    log "Checking required dependencies..." "info"

    local packages_to_install=()

    # Check for jq (required for JSON parsing)
    if ! command_exists jq; then
        log "jq is not installed. Adding to installation list." "info"
        packages_to_install+=("jq")
    fi

    # Check for curl (required for API requests)
    if ! command_exists curl; then
        log "curl is not installed. Adding to installation list." "info"
        packages_to_install+=("curl")
    fi

    # Check for wget (required for downloading CheckMk package)
    if ! command_exists wget; then
        log "wget is not installed. Adding to installation list." "info"
        packages_to_install+=("wget")
    fi

    # Check for lshw (required for system info collection)
    if ! command_exists lshw; then
        log "lshw is not installed. Adding to installation list." "info"
        packages_to_install+=("lshw")
    fi

    # Install required packages if any are missing
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log "Updating package repository..." "info"
        execute_task "Updating package repository" "apt update -qq"

        local packages_str="${packages_to_install[*]}"
        log "Installing required packages: $packages_str" "info"
        execute_task "Installing required packages" "DEBIAN_FRONTEND=noninteractive apt install -y -qq ${packages_str}"
    else
        log "All required dependencies are already installed." "success"
    fi
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

# Check for configuration files
check_config_files() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "Configuration file not found: $CONFIG_FILE" "error"
        exit 1
    fi
}

# Load configuration from JSON file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log "Loading configuration from $CONFIG_FILE" "info"
        if command_exists jq; then
            # Validate JSON format
            if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
                log "Invalid JSON format in $CONFIG_FILE" "error"
                log "Please check the file format and ensure it starts with '{' and ends with '}'" "info"
                exit 1
            fi

            # Extract all configuration
            SITE_NAME=$(jq -r '.site_name' "$CONFIG_FILE")
            CHECKMK_VERSION=$(jq -r '.checkmk_version' "$CONFIG_FILE")
            EXPECTED_HASH=$(jq -r '.expected_hash' "$CONFIG_FILE")

            log "Loading folders from configuration" "debug"
            readarray -t FOLDER_NAMES < <(jq -r '.folders[].name' "$CONFIG_FILE" 2>/dev/null)
            readarray -t FOLDER_TITLES < <(jq -r '.folders[].title' "$CONFIG_FILE" 2>/dev/null)

            FOLDERS=()

            # Build folder dictionary
            for i in "${!FOLDER_NAMES[@]}"; do
                FOLDERS+=("${FOLDER_NAMES[$i]}|${FOLDER_TITLES[$i]}")
                log "Added folder: ${FOLDER_NAMES[$i]} (${FOLDER_TITLES[$i]})" "debug"
            done

            log "Loaded ${#FOLDERS[@]} folders from configuration" "info"

            local missing_fields=()

            if [ -z "$SITE_NAME" ] || [ "$SITE_NAME" = "null" ]; then
                missing_fields+=("site_name")
            fi

            if [ -z "$CHECKMK_VERSION" ] || [ "$CHECKMK_VERSION" = "null" ]; then
                missing_fields+=("checkmk_version")
            fi

            if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" = "null" ]; then
                missing_fields+=("expected_hash")
            fi

            if [ ${#FOLDERS[@]} -eq 0 ]; then
                missing_fields+=("folders")
            fi

            if [ ${#missing_fields[@]} -gt 0 ]; then
                log "Missing required configuration fields in $CONFIG_FILE:" "error"
                for field in "${missing_fields[@]}"; do
                    echo " - $field"
                done
                exit 1
            fi
        else
            log "jq is required but not installed" "error"
            log "Install jq with: apt-get install -y jq" "info"
            exit 1
        fi
    else
        log "No configuration file found" "error"
        exit 1
    fi

    # Set derived variables based on loaded configuration
    PACKAGE_FILE="check-mk-raw-${CHECKMK_VERSION}_0.jammy_amd64.deb"
    DOWNLOAD_URL="https://download.checkmk.com/checkmk/${CHECKMK_VERSION}/${PACKAGE_FILE}"
}

# Collect system information
collect_system_info() {
    local dir_name=$1

    mkdir -p "$dir_name" && cd "$dir_name"

    execute_task "Collecting installed packages" "dpkg --get-selections > packages.txt"
    execute_task "Collecting open ports" "ss -tuln > ports.txt"
    execute_task "Collecting running services" "systemctl list-units --type=service --state=running > services.txt"
    execute_task "Collecting service statuses" "service --status-all > services-status.txt"
    execute_task "Collecting hardware information" "lshw -short > hardware.txt"
    execute_task "Collecting disk information" "lsblk > disks.txt"
    execute_task "Backing up sources list" "cp /etc/apt/sources.list sources.list"
    execute_task "Collecting network configuration" "ip addr > network.txt"
    execute_task "Collecting DNS information" "cat /etc/resolv.conf > dns.txt"
    execute_task "Collecting process information" "ps aux > processes.txt"

    cd "$BASE_DIR"
}

make_api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local site_name=$4

    if [ -z "$SITE_PASSWORD" ]; then
        log "Cannot make API request: Site password not available yet" "error"
        return 1
    fi

    local auth_string=$(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)
    log "API Request to: $endpoint" "info"

    local api_url="http://localhost/${site_name}/check_mk/api/1.0${endpoint}"
    local response_file=$(mktemp)

    if [ -n "$data" ]; then
        curl --silent \
            --request "$method" \
            --header "Authorization: Basic ${auth_string}" \
            --header "Content-Type: application/json" \
            --header "Accept: application/json" \
            --data "$data" \
            --write-out "\n%{http_code}" \
            "$api_url" >"$response_file"
    else
        curl --silent \
            --request "$method" \
            --header "Authorization: Basic ${auth_string}" \
            --header "Content-Type: application/json" \
            --header "Accept: application/json" \
            --write-out "\n%{http_code}" \
            "$api_url" >"$response_file"
    fi

    local status_code=$(tail -n1 "$response_file")
    local response=$(sed '$ d' "$response_file")
    rm -f "$response_file"

    if [[ "$status_code" -lt 200 || "$status_code" -ge 300 ]]; then
        log "API Error (HTTP $status_code): $response" "error"
        return 1
    fi

    echo "$response"
    return 0
}

create_folder() {
    local folder_name=$1
    local folder_title=$2
    local parent="/"
    local site_name=$3

    log "Creating folder '$folder_name' in CheckMk" "info"

    local response=$(make_api_request "POST" "/domain-types/folder_config/collections/all" \
        "{\"name\":\"$folder_name\",\"title\":\"$folder_title\",\"parent\":\"$parent\"}" \
        "$site_name")

    if echo "$response" | grep -q "id"; then
        log "Successfully created folder '$folder_name'" "success"
        return 0
    else
        log "Failed to create folder '$folder_name': $response" "error"
        return 1
    fi
}

folder_exists() {
    local folder_input=$1
    local folder_name="${folder_input%%|*}"

    for folder in "${FOLDERS[@]}"; do
        local name="${folder%%|*}"
        if [ "$name" = "$folder_name" ]; then
            return 0
        fi
    done

    return 1
}

get_folder_title() {
    local folder_name=$1
    local default_title=$2

    for folder in "${FOLDERS[@]}"; do
        local name="${folder%%|*}"
        local title="${folder#*|}"

        if [ "$name" = "$folder_name" ]; then
            echo "$title"
            return 0
        fi
    done

    echo "$default_title"
    return 0
}

add_host() {
    local hostname=$1
    local ipaddress=$2
    local folder=$3
    local site_name=$4

    if ! folder_exists "$folder"; then
        log "Folder '$folder' not defined in configuration, skipping host '$hostname'" "warning"
        return 0
    fi

    local folder_name="${folder%%|*}"

    log "Adding host '$hostname' to folder '$folder_name'" "info"

    local response=$(make_api_request "POST" "/domain-types/host_config/collections/all?bake_agent=false" \
        "{\"host_name\":\"$hostname\",\"folder\":\"/$folder_name\",\"attributes\":{\"ipaddress\":\"$ipaddress\"}}" \
        "$site_name")

    if echo "$response" | grep -q "id"; then
        log "Successfully added host '$hostname'" "success"
        return 0
    else
        log "Failed to add host '$hostname': $response" "error"
        return 1
    fi
}

add_hosts_from_config() {
    local site_name=$1
    local added_hosts=() # Track hostnames already added

    if [ -f "$CONFIG_FILE" ] && command_exists jq; then
        log "Adding hosts from configuration file" "info"

        jq -c '.hosts[]' "$CONFIG_FILE" 2>/dev/null | while read -r host; do
            local hostname=$(echo "$host" | jq -r '.hostname')
            local ipaddress=$(echo "$host" | jq -r '.ipaddress')
            local folder=$(echo "$host" | jq -r '.folder')

            if [ -z "$hostname" ] || [ -z "$folder" ]; then
                log "Skipping host with missing hostname or folder" "warning"
                continue
            fi

            local is_duplicate=false
            for existing_host in "${added_hosts[@]}"; do
                if [ "$existing_host" = "$hostname" ]; then
                    is_duplicate=true
                    break
                fi
            done

            if [ "$is_duplicate" = true ]; then
                log "Skipping duplicate hostname '$hostname' (already added to a different folder)" "warning"
                continue
            fi

            if ! folder_exists "$folder"; then
                log "Folder '$folder' not found in configuration, skipping host '$hostname'" "warning"
                continue
            fi

            if add_host "$hostname" "$ipaddress" "$folder" "$site_name"; then
                added_hosts+=("$hostname")
            fi
        done
    else
        log "No configuration file with hosts found or jq not installed" "warning"
    fi
}

activate_changes() {
    local site_name=$1

    log "Activating changes in CheckMk (this might take a moment)..." "info"

    local etag_response=$(curl --silent \
        --request GET \
        --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
        --header "Accept: application/json" \
        --include \
        "http://localhost/${site_name}/check_mk/api/1.0/domain-types/activation_run/collections/all")

    local etag=$(echo "$etag_response" | grep -i "ETag:" | head -n1 | awk '{print $2}' | tr -d '\r')

    if [ -z "$etag" ]; then
        log "Using default Etag value" "debug"
        etag="*"
    else
        log "Found Etag: $etag" "debug"
    fi

    local response=$(curl --silent \
        --request POST \
        --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "If-Match: $etag" \
        --data "{\"force_foreign_changes\":true}" \
        --write-out "\n%{http_code}" \
        "http://localhost/${site_name}/check_mk/api/1.0/domain-types/activation_run/actions/activate-changes/invoke")

    local status_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | sed '$d')

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
        log "Successfully activated changes" "success"
        return 0
    else
        log "Failed to activate changes: $response_body" "error"
        return 1
    fi
}

wait_for_api() {
    local site_name=$1
    local max_attempts=30
    local attempt=0
    local delay=5
    local last_info_output=0

    log "Waiting for CheckMk API to be ready..." "info"

    if [ -z "$SITE_PASSWORD" ]; then
        log "Cannot check API: Site password not available" "error"
        return 1
    fi

    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))

        if [ "$DEBUG_MODE" = false ] && [ $((attempt % 5)) -eq 0 ]; then
            log "Still waiting for API to be ready (attempt $attempt/$max_attempts)..." "info"
        fi

        local status_code=$(curl --silent --output /dev/null \
            --write-out "%{http_code}" \
            --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
            --header "Accept: application/json" \
            "http://localhost/${site_name}/check_mk/api/1.0/version")

        log "API check attempt $attempt/$max_attempts - Status code: $status_code" "debug"

        if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
            log "API is ready (attempt $attempt/$max_attempts)" "success"
            return 0
        elif [[ "$status_code" -eq 401 ]]; then
            log "API authentication failed - check credentials (attempt $attempt/$max_attempts)" "warning"
        elif [[ "$status_code" -eq 400 ]]; then
            # Try alternative endpoint if first one gives 400 error
            log "Bad request (400) with version endpoint, trying domain-types endpoint" "debug"

            status_code=$(curl --silent --output /dev/null \
                --write-out "%{http_code}" \
                --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
                --header "Accept: application/json" \
                "http://localhost/${site_name}/check_mk/api/1.0/domain-types")

            if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
                log "API is ready (using alternative endpoint)" "success"
                return 0
            fi
        fi

        log "API not ready yet, waiting $delay seconds... (attempt $attempt/$max_attempts)" "info"
        sleep $delay
    done

    log "API did not become ready after $max_attempts attempts" "error"

    # Final attempt with fully explicit request to help diagnose the issue
    log "Making final diagnostic request..." "info"
    curl --verbose \
        --request GET \
        --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
        --header "Accept: application/json" \
        "http://localhost/${site_name}/check_mk/api/1.0/version" 2>&1 | grep -v "Authorization:"

    return 1
}

# Main script execution starts here

# Check if root
check_root

# Install required dependencies
install_dependencies

# Check configuration files
check_config_files

# Load configuration
load_config

# Create directory for pre-installation system information
collect_system_info "PreInstallationData"

# Update and upgrade packages
execute_task "Updating package repository" "apt update -qq"
execute_task "Upgrading packages" "DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq" "true"

# Download CheckMk package
log "Downloading CheckMk package..." "info"

if [ -f "$PACKAGE_FILE" ]; then
    log "Package file already exists" "info"
else
    log "Downloading file from $DOWNLOAD_URL" "info" "true"
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

# Install CheckMk package
execute_task "Installing CheckMk package" "DEBIAN_FRONTEND=noninteractive apt install -y -q ./$PACKAGE_FILE" "true"

# Verify installation
if command_exists omd; then
    INSTALLED_VERSION=$(omd version | grep -oP 'Version \K[^ ]+')
    log "CheckMk version $INSTALLED_VERSION installed" "success"
else
    log "CheckMk installation failed - omd command not found" "error"
    exit 1
fi

# System information after installation
collect_system_info "PostInstallationData"

# Create and configure monitoring site
execute_task "Creating monitoring site '$SITE_NAME'" "omd create $SITE_NAME > site_creation.tmp" "true"

# Extract site password
SITE_PASSWORD=$(grep -oP 'cmkadmin with password: \K[^ ]+' site_creation.tmp)
if [ -n "$SITE_PASSWORD" ]; then
    log "Site created with auto-generated password" "success"
else
    log "Could not extract site password - cannot continue" "error"
    exit 1
fi
rm -f site_creation.tmp

# Start the monitoring site
execute_task "Starting monitoring site" "omd start $SITE_NAME"
check_site_status "$SITE_NAME"

# Wait for API readiness
wait_for_api "$SITE_NAME" || exit 1

# Create folders from configuration
log "Creating folders from configuration..." "info"
for folder in "${FOLDERS[@]}"; do
    folder_name="${folder%%|*}"
    folder_title="${folder#*|}"

    create_folder "$folder_name" "$folder_title" "$SITE_NAME"
done

# Add hosts from configuration
add_hosts_from_config "$SITE_NAME"

activate_changes "$SITE_NAME"

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
