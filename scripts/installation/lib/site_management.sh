#!/bin/bash

# =============================================================================
# Title:        CheckMk Site Management Module
# Description:  Functions for creating and managing CheckMk monitoring sites
#               Handles site creation, configuration, and status monitoring
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-06-10
# Version:      1.1.0
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Check if a monitoring site already exists
check_site_exists() {
  local site_name=$1
  if omd sites | grep -q "$site_name"; then
    return 0 # Site exists
  else
    return 1 # Site doesn't exist
  fi
}

# Create and configure monitoring site - updated for better password handling
create_monitoring_site() {
  local site_name=$1
  execute_with_spinner "Creating monitoring site '$site_name'" "omd create $site_name > site_creation.tmp"

  # Extract site password but handle it securely
  SITE_PASSWORD=$(grep -oP 'cmkadmin with password: \K[^ ]+' site_creation.tmp)

  if [ -n "$SITE_PASSWORD" ]; then
    # Don't include the actual password in logs, just confirmation it was generated
    log "Site created with auto-generated password" "success"

    # Save the password to a secure file in the user's home directory
    local password_file="$HOME/.checkmk_site_${site_name}_password"
    echo "$SITE_PASSWORD" >"$password_file"
    chmod 600 "$password_file"
    log "Password saved to secure file: $password_file" "info"
  else
    log "Could not extract site password - cannot continue" "error"
    exit 1
  fi

  # Securely remove the temporary file with the password
  shred -u site_creation.tmp 2>/dev/null || rm -f site_creation.tmp

  # Start the monitoring site
  execute_with_spinner "Starting monitoring site" "omd start $site_name"
}

# Start an existing monitoring site
start_monitoring_site() {
  local site_name=$1
  execute_with_spinner "Starting monitoring site" "omd start $site_name"
}

# Setup monitoring site (create new or use existing)
setup_monitoring_site() {
  # Check if site already exists
  if check_site_exists "$SITE_NAME"; then
    log "Site '$SITE_NAME' already exists" "warning"

    # Check site status
    local site_status=$(omd status "$SITE_NAME" 2>/dev/null)
    if echo "$site_status" | grep -q "Overall state:.*running"; then
      log "Existing site is already running" "info"
    else
      log "Existing site is not running, attempting to start it" "warning"
      start_monitoring_site "$SITE_NAME"
    fi

    # Get the site password by extracting it from the htpasswd file
    # This is needed for API access to the existing site
    log "Extracting password for existing site..." "info"
    SITE_PASSWORD=$(omd config "$SITE_NAME" show AUTH_PASSWORD_STORE 2>/dev/null | grep -v "AUTH_PASSWORD_STORE:")

    if [ -z "$SITE_PASSWORD" ]; then
      log "Could not extract password automatically" "warning"
      log "You may need to manually check the site and restart the script" "info"
      exit 1
    else
      log "Successfully obtained site credentials" "success"
    fi
  else
    # Create and configure a new monitoring site
    create_monitoring_site "$SITE_NAME"
  fi

  # Check final site status
  check_site_status "$SITE_NAME"
}

# Wait for API with improved error handling
wait_for_api_with_spinner() {
  local site_name=$1
  local max_attempts=${API_MAX_ATTEMPTS}
  local attempt=0
  local delay=${API_RETRY_DELAY}

  if [ -z "$SITE_PASSWORD" ]; then
    log "Cannot check API: Site password not available" "error"
    return 1
  fi

  log "Waiting for CheckMk API to become ready (max ${max_attempts} attempts)..." "info"
  log "API URL: ${API_BASE_URL}/${site_name}" "info"

  local sp='/-\|'
  local start_time=$(date +%s)

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    local elapsed=$(($(date +%s) - start_time))

    # Use carriage return to overwrite the line instead of printing new lines
    printf "\r[$timestamp] [\033[34mINFO\033[0m] Checking API readiness (attempt $attempt/$max_attempts) %c (%ds)" "${sp:attempt%4:1}" "$elapsed"

    local status_code=$(curl --silent --output /dev/null \
      --write-out "%{http_code}" \
      --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
      --header "Accept: application/json" \
      "${API_BASE_URL}/${site_name}/check_mk/api/1.0/version")

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
      printf "\r                                                                                  \r"
      log "API is ready (attempt $attempt/$max_attempts, time: ${elapsed}s)" "success"
      return 0
    elif [[ "$status_code" -eq 401 ]]; then
      printf "\r                                                                                  \r"
      log "API authentication failed - incorrect credentials (attempt $attempt/$max_attempts)" "warning"
    elif [[ "$status_code" -eq 400 ]]; then
      # Try alternative endpoint if first one gives 400 error
      status_code=$(curl --silent --output /dev/null \
        --write-out "%{http_code}" \
        --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
        --header "Accept: application/json" \
        "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types")

      if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
        printf "\r                                                                                  \r"
        log "API is ready using alternative endpoint (attempt $attempt/$max_attempts)" "success"
        return 0
      fi
    fi

    # Additional troubleshooting for non-localhost setups
    if [ "$API_HOST" != "localhost" ] && [ $attempt -eq 2 ] && [ "$status_code" = "000" ]; then
      log "Connection failure detected. Since you're using a custom host ($API_HOST:$API_PORT), check:" "warning"
      log "1. Network connectivity to the specified host and port" "info"
      log "2. Firewall settings allowing traffic to this port" "info"
      log "3. Correct host/port configuration in config.json" "info"
    fi

    sleep $delay
  done

  printf "\r                                                                                  \r"
  log "API did not become ready after $max_attempts attempts (${total_time}s)" "error"
  log "Check if the CheckMk site is running with 'omd status $site_name'" "info"
  return 1
}
