#!/bin/bash

# =============================================================================
# Title:        CheckMk Installation Script
# Description:  Automated installation and configuration of CheckMk monitoring
#               Creates site, folders, and adds hosts from config.json
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2025-06-12
# Version:      2.0.1
#
# Requirements:
#   - Ubuntu/Debian-based system
#   - Root privileges (run with sudo)
#   - Internet connection
#   - config.json file in same directory as script
#
# Usage:        sudo ./setup.sh [OPTION]...
# =============================================================================

# Exit script on error
set -e

# Record start time for duration calculation
INSTALLATION_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# Path variables
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="${SCRIPT_DIR}/lib"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
BASE_DIR=$(pwd)

# Operation flags
DEBUG_MODE=false
DO_INSTALL=false
DO_INSTALL_AGENT=false
DO_ADD_HOSTS=false
SHOW_HELP_ONLY=false

# Variables populated from config files
SITE_NAME=""
CHECKMK_VERSION=""
EXPECTED_HASH=""
FOLDERS=()
PACKAGE_FILE=""
DOWNLOAD_URL=""
SITE_PASSWORD=""
LOG_FILE=""

show_help() {
    echo "Usage: sudo setup.sh [OPTION]..."
    echo "Automated installation and configuration of CheckMk monitoring."
    echo
    echo "Options:"
    echo "  --help                 Display this help message and exit"
    echo "  --debug                Enable debug output (show all debug messages)"
    echo "  --install              Install CheckMk server and dashboard"
    echo "  --install-agent        Install CheckMk agent"
    echo "                         (works with existing sites or with --install)"
    echo "  --add-hosts            Add hosts from configuration file"
    echo "                         (works with existing sites or with --install)"
    echo
    echo "Example:"
    echo "  sudo setup.sh --install --add-hosts               # Install CheckMk and add hosts"
    echo "  sudo setup.sh --add-hosts                         # Add hosts to existing site"
    echo "  sudo setup.sh --install-agent                     # Install agent for existing site"
    echo
    echo "Note: Running without arguments will display this help message."
}

parse_arguments() {
    # Show help when no arguments provided
    if [ $# -eq 0 ]; then
        SHOW_HELP_ONLY=true
        show_help
        exit 0
    fi

    # Define valid options for typo detection
    local valid_options=("--help" "--debug" "--install" "--install-agent" "--add-hosts")

    while [ $# -gt 0 ]; do
        local arg="$1"
        case "$arg" in
        --help)
            SHOW_HELP_ONLY=true
            show_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=true
            ;;
        --install)
            DO_INSTALL=true
            ;;
        --install-agent)
            DO_INSTALL_AGENT=true
            ;;
        --add-hosts)
            DO_ADD_HOSTS=true
            ;;
        *)
            # Suggest corrections for possible typos
            echo -e "\033[31mError: Unknown option: $arg\033[0m"

            local closest_match=""
            local closest_distance=100

            for option in "${valid_options[@]}"; do
                if [[ "$arg" == --* && ${#arg} -gt 3 ]]; then
                    if [[ "${option:0:3}" == "${arg:0:3}" && ${#option} -gt 3 ]]; then
                        local diff=$((${#option} - ${#arg}))
                        diff=${diff#-}

                        if [[ $diff -lt $closest_distance ]]; then
                            closest_distance=$diff
                            closest_match=$option
                        fi
                    fi
                fi
            done

            if [[ -n "$closest_match" ]]; then
                echo -e "Did you mean \033[32m$closest_match\033[0m?"
            fi

            echo "Run 'sudo setup.sh --help' for usage information."
            exit 1
            ;;
        esac
        shift
    done

    # Show help if no operations specified
    if [ "$DO_INSTALL" = false ] && [ "$DO_INSTALL_AGENT" = false ] && [ "$DO_ADD_HOSTS" = false ] &&
        [ "$DEBUG_MODE" = false ]; then
        SHOW_HELP_ONLY=true
        show_help
        exit 0
    fi
}

# Minimal log function for early startup
log() {
    local message=$1
    local level=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Console output (skip debug unless in debug mode)
    if [ "$level" != "debug" ] || [ "$DEBUG_MODE" = true ]; then
        case "$level" in
        "success") echo -e "[$timestamp] [\033[32mSUCCESS\033[0m] $message" ;;
        "error") echo -e "[$timestamp] [\033[31mERROR\033[0m] $message" ;;
        "warning") echo -e "[$timestamp] [\033[33mWARNING\033[0m] $message" ;;
        "info") echo -e "[$timestamp] [\033[34mINFO\033[0m] $message" ;;
        "debug") echo -e "[$timestamp] [\033[35mDEBUG\033[0m] $message" ;;
        *) echo -e "[$timestamp] [$level] $message" ;;
        esac
    fi

    # Always log everything to file if available
    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] [${level^^}] $message" >>"$LOG_FILE"
    fi
}

setup_logging() {
    LOG_DIR="/var/log/checkmk-setup"
    [ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

    LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOG_FILE="${LOG_DIR}/checkmk_setup_${LOG_TIMESTAMP}.log"

    # Create symlink to latest log
    LATEST_LOG_LINK="${LOG_DIR}/latest.log"
    ln -sf "$LOG_FILE" "$LATEST_LOG_LINK"
}

load_libraries() {
    source "${LIB_DIR}/config.sh"
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/system_checks.sh"
    source "${LIB_DIR}/config_loader.sh"
    source "${LIB_DIR}/system_info.sh"
    source "${LIB_DIR}/installation.sh"
    source "${LIB_DIR}/site_management.sh"
    source "${LIB_DIR}/api_operations.sh"
    source "${LIB_DIR}/entity_management.sh"

    # Handle optional modules
    if [ -f "${LIB_DIR}/log_rotation.sh" ]; then
        source "${LIB_DIR}/log_rotation.sh"
    else
        # Define minimal fallback functions
        setup_log_directory() { return 0; }
        rotate_logs() { return 0; }
        create_log_summary() { return 0; }
        log "Warning: log_rotation.sh module not found, using defaults" "warning"
    fi
}

show_banner() {
    log "================================================================" "info"
    log "                 CheckMk Installation Script                    " "info"
    log "                       Version 2.0.1                            " "info"
    log "================================================================" "info"

    local os_info=$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
    local kernel_info=$(uname -r)
    local hostname_info=$(hostname)

    log "System:  $os_info ($kernel_info)" "info"
    log "Host:    $hostname_info" "info"
    log "Started: $(date +"%Y-%m-%d %H:%M:%S")" "info"
    log "Log:     $LOG_FILE" "info"

    if [ "$DEBUG_MODE" = true ]; then
        log "Debug:   ENABLED" "info"
    fi

    log "================================================================" "info"
}

main() {
    # Process arguments first
    parse_arguments "$@"

    # Check for operations requiring existing CheckMk
    if [ "$DO_INSTALL" = false ] && ([ "$DO_INSTALL_AGENT" = true ] || [ "$DO_ADD_HOSTS" = true ]); then
        if ! command -v omd >/dev/null 2>&1; then
            echo -e "\033[31mERROR: CheckMk is not installed on this system\033[0m"
            echo
            echo "Before you can add hosts or install agents, you must first install"
            echo "the CheckMk server using the --install option."
            echo
            echo -e "\033[1mREQUIRED ACTION:\033[0m"
            echo "  Run: sudo setup.sh --install"
            echo
            echo "For a complete setup including hosts:"
            echo "  Run: sudo setup.sh --install --add-hosts"
            echo
            exit 1
        fi
    fi

    # Setup logging
    setup_logging

    # Load libraries
    load_libraries

    # Configure log directory with fallback
    if ! setup_log_directory "$LOG_DIR"; then
        LOG_DIR="$SCRIPT_DIR/logs"
        mkdir -p "$LOG_DIR"
        LOG_FILE="${LOG_DIR}/checkmk_setup_${LOG_TIMESTAMP}.log"
        LATEST_LOG_LINK="${LOG_DIR}/latest.log"
        ln -sf "$LOG_FILE" "$LATEST_LOG_LINK"
    fi

    # Maintain log history
    rotate_logs "$LOG_DIR" 30

    show_banner

    # Register cleanup handler
    trap cleanup_on_exit INT TERM EXIT

    log "Checking root privileges..." "info"
    check_root

    install_dependencies
    check_config_files
    load_config

    # Handle operations with existing CheckMk installation
    if [ "$DO_INSTALL" = false ] && ([ "$DO_INSTALL_AGENT" = true ] || [ "$DO_ADD_HOSTS" = true ]); then
        log "Checking if site '$SITE_NAME' exists..." "info"

        if check_site_exists "$SITE_NAME"; then
            log "Site '$SITE_NAME' exists, proceeding with operations" "info"

            # Ensure site is running
            local site_status=$(omd status "$SITE_NAME" 2>/dev/null)
            if echo "$site_status" | grep -q "Overall state:.*running"; then
                log "Site is running" "info"
            else
                log "Site is not running, attempting to start it" "warning"
                start_monitoring_site "$SITE_NAME"
            fi

            # Get password for API access if needed
            if [ "$DO_ADD_HOSTS" = true ]; then
                if ! get_site_password "$SITE_NAME"; then
                    log "Cannot continue without valid site password" "error"
                    exit 1
                fi
            fi

            # Handle agent installation
            if [ "$DO_INSTALL_AGENT" = true ]; then
                if check_agent_installed; then
                    log "CheckMk agent is already installed on this system" "info"
                    log "Agent status: $(systemctl is-active check_mk_agent.socket)" "info"

                    log "Do you want to reinstall the agent? (y/n)" "info"
                    read -n 1 -r response
                    echo ""

                    if [[ $response =~ ^[Yy]$ ]]; then
                        log "Proceeding with agent reinstallation" "info"
                        log "Starting CheckMk agent installation process..." "info"
                        install_checkmk_agent
                        display_agent_summary
                    else
                        log "Skipping agent installation" "info"
                    fi
                else
                    log "Starting CheckMk agent installation process..." "info"
                    install_checkmk_agent
                    display_agent_summary
                fi
            fi

            # Handle host configuration
            if [ "$DO_ADD_HOSTS" = true ]; then
                if ! wait_for_api "$SITE_NAME"; then
                    log "API not available - cannot continue" "error"
                    exit 1
                fi

                log "Creating folders from configuration..." "info"
                create_folders_from_config

                log "Starting host configuration process..." "info"

                local host_add_retries=3
                local host_add_success=false

                for ((i = 1; i <= $host_add_retries; i++)); do
                    log "Host addition attempt $i/$host_add_retries" "info"

                    if add_hosts_from_config "$SITE_NAME"; then
                        host_add_success=true
                        log "Successfully added hosts from configuration" "success"
                        break
                    else
                        log "Host addition attempt $i failed, retrying..." "warning"
                        sleep 3
                    fi
                done

                if [ "$host_add_success" = false ]; then
                    log "Failed to add hosts after $host_add_retries attempts" "error"
                    log "Manual intervention may be required" "info"
                fi

                # Apply changes to CheckMk
                log "Activating changes in CheckMk..." "info"
                if ! activate_changes "$SITE_NAME"; then
                    log "Warning: Standard activation failed, trying forced activation..." "warning"
                    if ! force_activation "$SITE_NAME"; then
                        log "Warning: Activation had issues, but hosts may still be configured correctly" "warning"
                    else
                        log "Force activation completed successfully" "success"
                    fi
                else
                    log "Activation completed successfully" "success"
                fi

                # Verify host configuration
                log "Verifying host configuration..." "info"
                local verified_count=0
                local failed_count=0
                local total_count=0

                jq -c '.hosts[]' "$CONFIG_FILE" 2>/dev/null | while read -r host; do
                    local hostname=$(echo "$host" | jq -r '.hostname')
                    total_count=$((total_count + 1))

                    if host_exists "$hostname" "$SITE_NAME"; then
                        log "Host '$hostname' verified in CheckMk" "success"
                        verified_count=$((verified_count + 1))
                    else
                        log "Warning: Host '$hostname' not found in CheckMk after configuration" "warning"
                        failed_count=$((failed_count + 1))
                    fi
                done

                log "Host verification complete: $verified_count verified, $failed_count not found" "info"
            fi

            display_summary

            log "Operations completed successfully" "success"
            log "Log file saved to: $LOG_FILE" "info"
            exit 0
        else
            log "Site '$SITE_NAME' does not exist" "error"
            log "You need to install CheckMk first using --install" "info"
            log "Example: sudo setup.sh --install --install-agent --add-hosts" "info"
            exit 1
        fi
    fi

    # Full installation process
    if [ "$DO_INSTALL" = true ]; then
        log "Starting CheckMk server installation process..." "info"

        collect_system_info "PreInstallationData"

        if ! update_system_packages; then
            log "Warning: System package update had issues, but continuing with installation" "warning"
        fi

        download_checkmk_package

        install_checkmk

        collect_system_info "PostInstallationData"

        setup_monitoring_site

        wait_for_api "$SITE_NAME" || exit 1

        create_folders_from_config

        if [ "$DO_ADD_HOSTS" = true ]; then
            log "Starting host configuration process..." "info"

            local host_add_retries=3
            local host_add_success=false

            for ((i = 1; i <= $host_add_retries; i++)); do
                log "Host addition attempt $i/$host_add_retries" "info"

                if add_hosts_from_config "$SITE_NAME"; then
                    host_add_success=true
                    log "Successfully added hosts from configuration" "success"
                    break
                else
                    log "Host addition attempt $i failed, retrying..." "warning"
                    sleep 3
                fi
            done

            if [ "$host_add_success" = false ]; then
                log "Failed to add hosts after $host_add_retries attempts" "error"
                log "Manual intervention may be required" "info"
            fi

            log "Activating changes in CheckMk..." "info"
            if ! activate_changes "$SITE_NAME"; then
                log "Standard activation failed, trying forced activation..." "warning"
                force_activation "$SITE_NAME"
            fi
        fi

        log "CheckMk server installation complete" "success"
    fi

    # Show installation summary
    if [ "$DO_INSTALL" = true ] || [ "$DO_ADD_HOSTS" = true ] || [ "$DO_INSTALL_AGENT" = true ]; then
        display_summary
    fi

    # Create log summary silently
    if type create_log_summary &>/dev/null; then
        create_log_summary "$LOG_DIR" >/dev/null 2>&1
    fi
}

cleanup_on_exit() {
    local exit_code=$?

    if [ -n "$LOG_FILE" ]; then
        # Clean up temporary files
        rm -f /tmp/agent_*.log 2>/dev/null
        rm -f /tmp/folder_cache_*.txt 2>/dev/null

        # Remove empty logs
        if [ -f "$LOG_FILE" ] && [ ! -s "$LOG_FILE" ]; then
            rm -f "$LOG_FILE"
            return
        fi

        # Record script end time
        echo "[$timestamp] [INFO] Script finished at: $(date +"%Y-%m-%d %H:%M:%S")" >>"$LOG_FILE"
    fi
}

# Start the installation
main "$@"
exit 0
