#!/bin/bash

# =============================================================================
# CheckMk System Checks Module
# Functions for verifying system requirements and dependencies
# =============================================================================

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "This script must be run as root or with sudo privileges." "error"
    exit 1
  fi
}

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

  if [ ${#packages_to_install[@]} -gt 0 ]; then
    execute_with_spinner "Updating package repository" "apt update -qq" 300

    local packages_str="${packages_to_install[*]}"
    execute_with_spinner "Installing required packages" "DEBIAN_FRONTEND=noninteractive apt install -y -qq ${packages_str}" 600
  else
    log "All required dependencies are already installed." "success"
  fi
}

check_site_status() {
  local site_name=$1
  local status_output=$(omd status "$site_name")

  if echo "$status_output" | grep -q "Overall state:.*running"; then
    log "Site $site_name status" "success"
  else
    log "Site $site_name may not be running correctly" "warning"
  fi
}

check_agent_installed() {
  if dpkg -l | grep -q "check-mk-agent"; then
    log "CheckMk agent is already installed on this system" "debug"
    return 0
  fi

  log "CheckMk agent is not installed" "debug"
  return 1
}

get_agent_status() {
  # Prioritize cmk-agent-ctl which works in both standard and WSL environments
  if command -v cmk-agent-ctl >/dev/null 2>&1; then
    local status_output=$(cmk-agent-ctl status 2>/dev/null)

    if echo "$status_output" | grep -q "Agent socket: operational"; then
      echo "operational"
      return 0
    elif echo "$status_output" | grep -q "Version:"; then
      echo "installed"
      return 0
    fi
  fi

  # Fall back to systemctl if cmk-agent-ctl isn't available
  if ! command -v cmk-agent-ctl >/dev/null 2>&1; then
    local systemd_status=$(systemctl is-active check_mk_agent.socket 2>/dev/null)
    if [ "$systemd_status" = "active" ]; then
      echo "active"
      return 0
    fi
  fi

  # Check for WSL environment with pending configuration
  if uname -r | grep -q "microsoft" || uname -r | grep -q "WSL"; then
    echo "wsl-pending"
    return 0
  fi

  echo "inactive"
  return 1
}

check_api_connectivity() {
  local site_name=$1
  local max_attempts=${2:-3}
  local retry_delay=${3:-2}
  local attempt=1

  log "Checking API connectivity for site $site_name..." "info"

  if [ -z "$SITE_PASSWORD" ]; then
    log "Site password not available - cannot check API connectivity" "error"
    return 1
  fi

  while [ $attempt -le $max_attempts ]; do
    log "API connectivity check attempt $attempt/$max_attempts" "debug"

    local status_code=$(curl --silent --output /dev/null \
      --write-out "%{http_code}" \
      --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
      --header "Accept: application/json" \
      "${API_BASE_URL}/${site_name}/check_mk/api/1.0/version")

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
      log "API connectivity check successful (status: $status_code)" "success"
      return 0
    else
      log "API connectivity check failed (status: $status_code) - attempt $attempt/$max_attempts" "warning"

      if [ $attempt -eq $max_attempts ]; then
        log "All API connectivity attempts failed" "error"
        log "Running API diagnostics..." "info"
        diagnose_api_issues "$site_name"
        return 1
      fi

      attempt=$((attempt + 1))
      sleep $retry_delay
    fi
  done

  return 1
}
