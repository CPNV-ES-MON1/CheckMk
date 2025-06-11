#!/bin/bash

# =============================================================================
# Title:        CheckMk Installation Script
# Description:  Automated installation and configuration of CheckMk monitoring
#               Creates site, folders, and adds hosts from config.json
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2025-06-10
# Version:      2.0.0
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

# Create logs directory if it doesn't exist
LOG_DIR="/var/log/checkmk-setup"
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

# Use timestamp in log filename for better history
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/checkmk_setup_${LOG_TIMESTAMP}.log"

# Create a symlink to the latest log for convenience
LATEST_LOG_LINK="${LOG_DIR}/latest.log"
ln -sf "$LOG_FILE" "$LATEST_LOG_LINK"

# Define a minimal version of the log function for early logging
# This will be replaced by the full version when common.sh is sourced
log() {
    local message=$1
    local level=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Print to console with color
    case "$level" in
    "success") echo -e "[$timestamp] [\033[32mSUCCESS\033[0m] $message" ;;
    "error") echo -e "[$timestamp] [\033[31mERROR\033[0m] $message" ;;
    "warning") echo -e "[$timestamp] [\033[33mWARNING\033[0m] $message" ;;
    "info") echo -e "[$timestamp] [\033[34mINFO\033[0m] $message" ;;
    "debug") echo -e "[$timestamp] [\033[35mDEBUG\033[0m] $message" ;;
    *) echo -e "[$timestamp] [$level] $message" ;;
    esac

    # Log to file if it exists
    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] [${level^^}] $message" >>"$LOG_FILE"
    fi
}

log "Log file created at: $LOG_FILE" "info"

# Operation flags
DEBUG_MODE=false
DO_INSTALL=false
DO_INSTALL_AGENT=false
DO_ADD_HOSTS=false

# Variables populated from config files
SITE_NAME=""
CHECKMK_VERSION=""
EXPECTED_HASH=""
FOLDERS=()
PACKAGE_FILE=""
DOWNLOAD_URL=""
SITE_PASSWORD=""

# Load library modules
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/system_checks.sh"
source "${LIB_DIR}/config_loader.sh"
source "${LIB_DIR}/system_info.sh"
source "${LIB_DIR}/installation.sh"
source "${LIB_DIR}/site_management.sh"
source "${LIB_DIR}/api_operations.sh"
source "${LIB_DIR}/entity_management.sh"

# Load log_rotation.sh module if it exists
if [ -f "${LIB_DIR}/log_rotation.sh" ]; then
    source "${LIB_DIR}/log_rotation.sh"
else
    # Define minimal versions of the log rotation functions
    setup_log_directory() { return 0; }
    rotate_logs() { return 0; }
    create_log_summary() { return 0; }
    log "Warning: log_rotation.sh module not found, using defaults" "warning"
fi

# Display script banner with version information - Improved clean version
show_banner() {
    log "================================================================" "info"
    log "                 CheckMk Installation Script                    " "info"
    log "                       Version 1.3.0                            " "info"
    log "================================================================" "info"
    log "Started at: $(date +"%Y-%m-%d %H:%M:%S")" "info"
    log "Log file: $LOG_FILE" "info"

    if [ "$DEBUG_MODE" = true ]; then
        log "Debug mode: ENABLED" "info"
    fi

    log "================================================================" "info"
}

# Display help message
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

# Parse command line arguments
parse_arguments() {
    # No arguments case
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # Process arguments
    while [ $# -gt 0 ]; do
        case "$1" in
        --help)
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
            echo "Error: Unknown option: $1"
            echo "Run 'sudo setup.sh --help' for usage information."
            exit 1
            ;;
        esac
        shift
    done

    # If no operations are specified but there are arguments, show help
    if [ "$DO_INSTALL" = false ] && [ "$DO_INSTALL_AGENT" = false ] && [ "$DO_ADD_HOSTS" = false ] &&
        [ "$DEBUG_MODE" = false ]; then
        show_help
        exit 0
    fi
}

# Display summary with masked password - show password in summary and don't save to file
display_summary() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    local installation_end_time=$(date +"%Y-%m-%d %H:%M:%S")

    # Create a visual separator for better readability
    log "================================================================" "info"
    log "                  Installation Summary                          " "info"
    log "================================================================" "info"

    if [ "$DO_INSTALL" = true ]; then
        log "CheckMk $INSTALLED_VERSION has been successfully installed" "info"
        log "Access the web interface: ${API_BASE_URL}/${SITE_NAME}/" "info"
        log "Credentials:" "info"
        log "  • Username: cmkadmin" "info"

        # Don't log the actual password, use a masked version for the logs
        local masked_password="*********"
        if [ ${#SITE_PASSWORD} -gt 3 ]; then
            # Show first and last character only
            masked_password="${SITE_PASSWORD:0:1}*******${SITE_PASSWORD: -1}"
        fi

        # Display password in the log with masking - don't save to file
        log "  • Password: $masked_password" "info"
        log "For CLI administration: omd su $SITE_NAME" "info"
    fi

    if [ "$DO_INSTALL_AGENT" = true ]; then
        log "CheckMk agent has been installed and configured" "info"
        log "Agent status: $(systemctl is-active check_mk_agent.socket)" "info"
    fi

    if [ "$DO_ADD_HOSTS" = true ]; then
        log "Hosts have been configured from config.json" "info"
        if [ "$DEBUG_MODE" = true ]; then
            local host_count=$(jq '.hosts | length' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
            log "Number of configured hosts: $host_count" "info"
        fi
    fi

    log "================================================================" "info"
}

# Cleanup function to run on exit - modified to not display duplicate information
cleanup_on_exit() {
    local exit_code=$?

    # Remove temporary files quietly
    rm -f /tmp/agent_*.log 2>/dev/null
    rm -f /tmp/folder_cache_*.txt 2>/dev/null

    # Remove empty logs to save space
    if [ -f "$LOG_FILE" ] && [ ! -s "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        return
    fi

    # Don't display anything else to avoid duplicate information
    # Just log end time to the log file
    echo "[$timestamp] [INFO] Script finished at: $(date +"%Y-%m-%d %H:%M:%S")" >>"$LOG_FILE"
}

# Main function - consolidate log creation at the end
main() {
    # Parse command line arguments first to set DEBUG_MODE
    parse_arguments "$@"

    # Setup log directory - use fallback if needed
    if ! setup_log_directory "$LOG_DIR"; then
        LOG_DIR="$SCRIPT_DIR/logs"
        mkdir -p "$LOG_DIR"
        LOG_FILE="${LOG_DIR}/checkmk_setup_${LOG_TIMESTAMP}.log"
        LATEST_LOG_LINK="${LOG_DIR}/latest.log"
        ln -sf "$LOG_FILE" "$LATEST_LOG_LINK"
    fi

    # Rotate old logs to prevent disk space issues
    rotate_logs "$LOG_DIR" 30

    # Show banner with script information
    show_banner

    # Add system info logging
    log "System information:" "info"
    log "  - OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')" "info"
    log "  - Kernel: $(uname -r)" "info"
    log "  - Hostname: $(hostname)" "info"
    log "  - Working directory: $BASE_DIR" "info"

    # Trap signals for clean exit
    trap cleanup_on_exit INT TERM EXIT

    # Check if root
    log "Checking root privileges..." "info"
    check_root

    # For other operations, continue with normal flow
    install_dependencies
    check_config_files
    load_config

    # Handle operations without --install
    if [ "$DO_INSTALL" = false ] && ([ "$DO_INSTALL_AGENT" = true ] || [ "$DO_ADD_HOSTS" = true ]); then
        log "Checking if site '$SITE_NAME' exists..." "info"

        # First check if site exists - required for both agent and add-hosts
        if check_site_exists "$SITE_NAME"; then
            log "Site '$SITE_NAME' exists, proceeding with operations" "info"

            # Check site status
            local site_status=$(omd status "$SITE_NAME" 2>/dev/null)
            if echo "$site_status" | grep -q "Overall state:.*running"; then
                log "Site is running" "info"
            else
                log "Site is not running, attempting to start it" "warning"
                start_monitoring_site "$SITE_NAME"
            fi

            # For agent installation
            if [ "$DO_INSTALL_AGENT" = true ]; then
                # First check if agent is already installed
                if check_agent_installed; then
                    log "CheckMk agent is already installed on this system" "info"
                    log "Agent status: $(systemctl is-active check_mk_agent.socket)" "info"

                    # Ask if user wants to reinstall
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
                    # Agent not installed, proceed with installation
                    log "Starting CheckMk agent installation process..." "info"
                    install_checkmk_agent
                    display_agent_summary
                fi
            fi

            # For adding hosts
            if [ "$DO_ADD_HOSTS" = true ]; then
                # Wait for API to be ready if we're using API operations
                wait_for_api "$SITE_NAME" || exit 1

                # IMPORTANT: Create folders first before adding hosts
                log "Creating folders from configuration..." "info"
                create_folders_from_config

                # Add hosts and activate changes - simplified flow with reduced retries
                log "Starting host configuration process..." "info"

                # Try once with a more robust function that handles internal retries
                if add_hosts_from_config "$SITE_NAME"; then
                    log "Host configuration completed successfully" "success"
                else
                    log "Warning: Some hosts may not have been added correctly" "warning"
                    log "Check the web interface to verify the host status" "info"
                fi

                # Always run activation regardless of add_hosts_from_config result
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

                # Verify hosts without excessive retries
                log "Verifying host configuration..." "info"
                jq -c '.hosts[]' "$CONFIG_FILE" 2>/dev/null | while read -r host; do
                    local hostname=$(echo "$host" | jq -r '.hostname')
                    if host_exists "$hostname" "$SITE_NAME"; then
                        log "Host '$hostname' verified in CheckMk" "success"
                    else
                        log "Warning: Host '$hostname' not found in CheckMk after configuration" "warning"
                    fi
                done
            fi

            # Display summary if any operations were performed
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

    # Handle full installation (when --install is specified)
    if [ "$DO_INSTALL" = true ]; then
        log "Starting CheckMk server installation process..." "info"

        # Create system information directory
        collect_system_info "PreInstallationData"

        # Update system packages with recovery
        if ! update_system_packages; then
            log "Warning: System package update had issues, but continuing with installation" "warning"
            # Continue anyway since package updates failing shouldn't stop the entire installation
        fi

        # Download and verify CheckMk package
        download_checkmk_package

        # Install CheckMk
        install_checkmk

        # Collect post-installation system information
        collect_system_info "PostInstallationData"

        # Setup monitoring site
        setup_monitoring_site

        # Wait for API to be ready
        wait_for_api "$SITE_NAME" || exit 1

        # Create folders from configuration
        create_folders_from_config

        log "CheckMk server installation complete" "success"

        # Install agent if requested
        if [ "$DO_INSTALL_AGENT" = true ]; then
            log "Starting CheckMk agent installation process..." "info"
            install_checkmk_agent
        fi
    fi

    # Display summary if any operations were performed
    if [ "$DO_INSTALL" = true ] || [ "$DO_ADD_HOSTS" = true ] || [ "$DO_INSTALL_AGENT" = true ]; then
        display_summary
    fi

    # At the end, create a log summary but don't print a message about it
    if type create_log_summary &>/dev/null; then
        create_log_summary "$LOG_DIR" >/dev/null 2>&1
    fi

    # Don't log anything here - we'll do all final output in cleanup_on_exit
}

# Cleanup function to run on exit - completely redesigned for a cleaner finish
cleanup_on_exit() {
    local exit_code=$?

    # Remove temporary files quietly
    rm -f /tmp/agent_*.log 2>/dev/null
    rm -f /tmp/folder_cache_*.txt 2>/dev/null

    # Remove empty logs to save space
    if [ -f "$LOG_FILE" ] && [ ! -s "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        return
    fi

    # Don't display anything else to avoid duplicate information
    # Just log end time to the log file
    echo "[$timestamp] [INFO] Script finished at: $(date +"%Y-%m-%d %H:%M:%S")" >>"$LOG_FILE"
}

# Start the installation
main "$@"
exit 0
