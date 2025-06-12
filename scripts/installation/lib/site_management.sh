#!/bin/bash

# =============================================================================
# CheckMk Site Management Module
# Functions for creating and managing monitoring sites
# =============================================================================

check_site_exists() {
  local site_name=$1
  if omd sites | grep -q "$site_name"; then
    return 0 # Site exists
  else
    return 1 # Site doesn't exist
  fi
}

create_monitoring_site() {
  local site_name=$1
  execute_with_spinner "Creating monitoring site '$site_name'" "omd create $site_name > site_creation.tmp"

  # Extract password securely without saving to disk
  SITE_PASSWORD=$(grep -oP 'cmkadmin with password: \K[^ ]+' site_creation.tmp)

  if [ -n "$SITE_PASSWORD" ]; then
    log "Site created with auto-generated password" "success"
    log "Password will be displayed only in the final summary" "info"
  else
    log "Could not extract site password - cannot continue" "error"
    exit 1
  fi

  # Remove the temporary file with the password
  shred -u site_creation.tmp 2>/dev/null || rm -f site_creation.tmp

  execute_with_spinner "Starting monitoring site" "omd start $site_name"
}

start_monitoring_site() {
  local site_name=$1
  execute_with_spinner "Starting monitoring site" "omd start $site_name"
}

setup_monitoring_site() {
  if check_site_exists "$SITE_NAME"; then
    log "Site '$SITE_NAME' already exists" "warning"

    local site_status=$(omd status "$SITE_NAME" 2>/dev/null)
    if echo "$site_status" | grep -q "Overall state:.*running"; then
      log "Existing site is already running" "info"
    else
      log "Existing site is not running, attempting to start it" "warning"
      start_monitoring_site "$SITE_NAME"
    fi

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
    create_monitoring_site "$SITE_NAME"
  fi

  check_site_status "$SITE_NAME"
}

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
      # Try alternative endpoint for compatibility with older versions
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

    # Help diagnose remote connection issues
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

prompt_for_site_password() {
  local site_name=$1

  log "Site password required for API operations" "info"
  log "Please enter the password for user 'cmkadmin'" "info"

  read -s -p "Password: " input_password
  echo ""

  if [ -z "$input_password" ]; then
    log "No password entered" "error"
    return 1
  fi

  SITE_PASSWORD="$input_password"

  log "Validating provided password..." "info"

  local status_code=$(curl --silent --output /dev/null \
    --write-out "%{http_code}" \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/version")

  if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
    log "Password validated successfully" "success"
    return 0
  elif [[ "$status_code" -eq 401 ]]; then
    log "Authentication failed: Incorrect password" "error"
    SITE_PASSWORD=""
    return 1
  else
    log "Unexpected error during authentication (status code: $status_code)" "error"
    log "Check site status and network connectivity" "info"
    SITE_PASSWORD=""
    return 1
  fi
}

get_site_password() {
  local site_name=$1
  local password_attempts=3
  local attempt=1

  log "Attempting to get site password for '$site_name'..." "debug"

  # Try system methods first if running as root
  if [ "$(id -u)" -eq 0 ]; then
    if omd exists "$site_name" >/dev/null 2>&1; then
      if [ -f "/omd/sites/$site_name/etc/htpasswd" ]; then
        log "Attempting to extract password from htpasswd file..." "debug"
        local extracted_pwd=$(grep "cmkadmin:" "/omd/sites/$site_name/etc/htpasswd" 2>/dev/null)

        if [ -n "$extracted_pwd" ]; then
          log "Found credentials in htpasswd file" "debug"
          SITE_PASSWORD="*****" # Security protection
          log "Password extraction not allowed for security reasons" "warning"
          log "Please enter password manually" "info"
          prompt_for_site_password "$site_name"
          return $?
        fi
      fi
    fi
  fi

  # Interactive password prompt with validation
  while [ $attempt -le $password_attempts ]; do
    if prompt_for_site_password "$site_name"; then
      return 0
    else
      if [ $attempt -lt $password_attempts ]; then
        log "Password validation failed, please try again (attempt $attempt/$password_attempts)" "warning"
        attempt=$((attempt + 1))
      else
        log "Failed to validate password after $password_attempts attempts" "error"
        return 1
      fi
    fi
  done

  return 1
}
