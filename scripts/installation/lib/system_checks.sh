#!/bin/bash

# =============================================================================
# Title:        CheckMk System Checks Module
# Description:  System validation functions for the CheckMk installation
#               Verifies system requirements and dependencies
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-05-28
# Version:      1.0.0
#
# Usage:        Sourced by setup.sh
# =============================================================================

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "This script must be run as root or with sudo privileges." "error"
    exit 1
  fi
}

# Install required dependencies with improved progress indicators
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
    # Don't log the message here - execute_with_spinner will show it
    execute_with_spinner "Updating package repository" "apt update -qq" 300

    local packages_str="${packages_to_install[*]}"
    # Don't log this message either - execute_with_spinner will show it
    execute_with_spinner "Installing required packages" "DEBIAN_FRONTEND=noninteractive apt install -y -qq ${packages_str}" 600
  else
    log "All required dependencies are already installed." "success"
  fi
}

# Check site status
check_site_status() {
  local site_name=$1
  local status_output=$(omd status "$site_name")

  if echo "$status_output" | grep -q "Overall state:.*running"; then
    log "Site $site_name status" "success"
  else
    log "Site $site_name may not be running correctly" "warning"
  fi
}

# Check if the CheckMk agent is already installed
check_agent_installed() {
  if dpkg -l | grep -q "check-mk-agent"; then
    log "CheckMk agent is already installed on this system" "debug"

    # Check if service is properly set up
    if systemctl list-unit-files | grep -q "check_mk_agent.socket"; then
      log "CheckMk agent service is properly installed" "debug"
      return 0
    fi

    log "CheckMk agent package is installed but service might not be properly configured" "debug"
    return 0
  fi

  log "CheckMk agent is not installed" "debug"
  return 1
}
