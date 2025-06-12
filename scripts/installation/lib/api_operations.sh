#!/bin/bash

# =============================================================================
# CheckMk API Operations Module
# Functions for interacting with the CheckMk REST API and handling responses
# =============================================================================

make_api_request() {
  local method=$1
  local endpoint=$2
  local data=$3
  local site_name=$4

  log "Making API request: $method $endpoint" "debug"

  if [ -z "$SITE_PASSWORD" ]; then
    log "Cannot make API request: Site password not available yet" "error"
    log "Make sure the site was created successfully before making API requests" "debug"
    return 1
  fi

  local auth_string=$(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)
  log "API Request to: $endpoint" "info"

  if [ -n "$data" ]; then
    log "Request data: $data" "debug"
  fi

  local api_url="${API_BASE_URL}/${site_name}/check_mk/api/1.0${endpoint}"
  local response_file=$(mktemp)
  log "Full API URL: $api_url" "debug"

  local start_time=$(date +%s.%N)

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

  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)
  local formatted_duration=$(printf "%.3f" $duration)

  local status_code=$(tail -n1 "$response_file")
  local response=$(sed '$ d' "$response_file")

  log "API response time: ${formatted_duration}s" "debug"
  log "Response status code: $status_code" "debug"

  if [ "$DEBUG_MODE" = true ] && [ -n "$response" ]; then
    log "Response body:" "debug"
    if command_exists jq && echo "$response" | jq . &>/dev/null; then
      echo "$response" | jq . | while read -r line; do
        log "  $line" "debug"
      done
    else
      log "  $response" "debug"
    fi
  fi

  rm -f "$response_file"

  if [[ "$status_code" -lt 200 || "$status_code" -ge 300 ]]; then
    log "API Error (HTTP $status_code): $response" "error"

    case "$status_code" in
    400) log "Bad request - The request syntax might be invalid" "debug" ;;
    401) log "Unauthorized - Authentication is required or failed" "debug" ;;
    403) log "Forbidden - The server understood the request but refuses to authorize it" "debug" ;;
    404) log "Not found - The requested resource could not be found" "debug" ;;
    409) log "Conflict - The request conflicts with the current state of the server" "debug" ;;
    500) log "Internal server error - The server encountered an unexpected condition" "debug" ;;
    503) log "Service unavailable - The server is currently unable to handle the request" "debug" ;;
    esac

    return 1
  fi

  echo "$response"
  return 0
}

wait_for_api() {
  local site_name=$1
  local max_attempts=${API_MAX_ATTEMPTS}
  local attempt=0
  local delay=${API_RETRY_DELAY}

  log "Waiting for CheckMk API to become ready..." "info"
  log "API URL: ${API_BASE_URL}/${site_name}" "debug"
  log "Maximum wait time: $((max_attempts * delay)) seconds" "debug"
  log "Check interval: $delay seconds" "debug"

  if [ -z "$SITE_PASSWORD" ]; then
    log "Cannot check API: Site password not available" "error"

    # For existing sites, try to get the password
    if check_site_exists "$site_name"; then
      log "Attempting to get password for existing site" "info"
      if ! get_site_password "$site_name"; then
        log "Failed to get site password" "error"
        return 1
      fi
    else
      log "Site might not have been created correctly" "debug"
      return 1
    fi
  fi

  local start_time=$(date +%s)

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    local elapsed=$(($(date +%s) - start_time))

    log "API check attempt $attempt/$max_attempts (elapsed: ${elapsed}s)" "debug"

    if [ "$DEBUG_MODE" = false ] && [ $((attempt % 2)) -eq 0 ]; then
      log "Still waiting for API to be ready (attempt $attempt/$max_attempts, elapsed: ${elapsed}s)..." "info"
    fi

    local status_code=$(curl --silent --output /dev/null \
      --write-out "%{http_code}" \
      --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
      --header "Accept: application/json" \
      "${API_BASE_URL}/${site_name}/check_mk/api/1.0/version")

    log "API check attempt $attempt/$max_attempts - Status code: $status_code" "debug"

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
      local total_time=$(($(date +%s) - start_time))
      log "API is ready (attempt $attempt/$max_attempts, total wait time: ${total_time}s)" "success"
      return 0
    elif [[ "$status_code" -eq 401 ]]; then
      # Authentication failure handling
      log "API authentication failed - incorrect password (attempt $attempt/$max_attempts)" "error"

      if [ $attempt -eq 3 ]; then
        log "Consistent authentication failures - password may be incorrect" "warning"
        if type -t prompt_for_site_password &>/dev/null; then
          log "Prompting for password again..." "info"
          if prompt_for_site_password "$site_name"; then
            log "New password provided, retrying API connection" "info"
            continue
          else
            log "Failed to get valid password" "error"
            return 1
          fi
        fi
      fi
    elif [[ "$status_code" -eq 400 ]]; then
      # Try alternative endpoint for older CheckMk versions
      log "Bad request (400) with version endpoint, trying domain-types endpoint" "debug"

      status_code=$(curl --silent --output /dev/null \
        --write-out "%{http_code}" \
        --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
        --header "Accept: application/json" \
        "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types")

      if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
        local total_time=$(($(date +%s) - start_time))
        log "API is ready using alternative endpoint (total wait time: ${total_time}s)" "success"
        return 0
      fi
    fi

    log "API not ready yet (status: $status_code), waiting $delay seconds... (attempt $attempt/$max_attempts)" "info"
    sleep $delay
  done

  local total_time=$(($(date +%s) - start_time))
  log "API did not become ready after $max_attempts attempts (${total_time}s)" "error"
  log "Check if the CheckMk site is running with 'omd status $site_name'" "info"

  # Final diagnostic request for troubleshooting
  log "Making final diagnostic request..." "info"
  log "Verbose curl output for troubleshooting:" "debug"
  curl --verbose \
    --request GET \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/version" 2>&1 | grep -v "Authorization:" | while read -r line; do
    log "  $line" "debug"
  done

  return 1
}

activate_changes() {
  local site_name=$1

  log "Activating changes in CheckMk..." "info"
  log "This might take a moment depending on the number of changes" "info"

  # Get ETag needed for activation request
  local etag_response=$(curl --silent \
    --request GET \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    --include \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/activation_run/collections/all")

  local etag=$(echo "$etag_response" | grep -i "ETag:" | head -n1 | awk '{print $2}' | tr -d '\r')

  if [ -z "$etag" ]; then
    log "Using default Etag value '*'" "debug"
    etag="*"
  else
    log "Found Etag: $etag" "debug"
  fi

  local start_time=$(date +%s)

  local response=$(curl --silent \
    --request POST \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --header "If-Match: $etag" \
    --data "{\"force_foreign_changes\":true}" \
    --write-out "\n%{http_code}" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/activation_run/actions/activate-changes/invoke")

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  local status_code=$(echo "$response" | tail -n1)
  local response_body=$(echo "$response" | sed '$d')

  log "Activation request processing time: ${duration}s" "debug"
  log "Response status code: $status_code" "debug"

  if [ "$DEBUG_MODE" = true ] && [ -n "$response_body" ]; then
    log "Response body:" "debug"
    if command_exists jq && echo "$response_body" | jq . &>/dev/null; then
      echo "$response_body" | jq . | while read -r line; do
        log "  $line" "debug"
      done
    else
      log "  $response_body" "debug"
    fi
  fi

  # 422 error indicates no pending changes to activate
  if [[ "$status_code" -eq 422 ]] && [[ "$response_body" == *"no changes to activate"* ]]; then
    log "No changes needed activation (hosts may already be configured)" "warning"
    return 0
  fi

  if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
    log "Successfully activated changes (processing time: ${duration}s)" "success"
    return 0
  else
    log "Failed to activate changes: $response_body" "error"
    log "Status code: $status_code" "error"

    if [ "$DEBUG_MODE" = true ]; then
      log "Activation troubleshooting:" "debug"
      log "  - Check if the site is running: omd status $site_name" "debug"
      log "  - Check if there are any conflicts in configuration" "debug"
      log "  - Check if the API user has permission to activate changes" "debug"
    fi

    # 422 errors are typically warnings, not critical failures
    if [[ "$status_code" -eq 422 ]]; then
      log "Non-critical error during activation, continuing..." "warning"
      return 0
    fi

    return 1
  fi
}

force_activation() {
  local site_name=$1
  local output_level=${2:-normal} # Can be 'normal', 'quiet', or 'verbose'
  local max_retries=5
  local retry_count=1
  local success=false

  if [ "$output_level" != "quiet" ]; then
    log "Forcing activation of changes in CheckMk..." "info"
  fi

  while [ $retry_count -le $max_retries ] && [ "$success" = false ]; do
    if [ "$output_level" != "quiet" ]; then
      log "Activation attempt $retry_count/$max_retries" "debug"
    fi

    local response=$(curl --silent \
      --request POST \
      --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
      --header "Content-Type: application/json" \
      --data "{\"force_foreign_changes\":true}" \
      --write-out "\n%{http_code}" \
      "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/activation_run/actions/activate-changes/invoke")

    local status_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | sed '$d')

    if [ "$output_level" = "verbose" ]; then
      log "API response code: $status_code" "debug"
      log "API response body: $response_body" "debug"
    fi

    if [ "$status_code" = "200" ] || [ "$status_code" = "201" ] || [ "$status_code" = "202" ]; then
      if [ "$output_level" != "quiet" ]; then
        log "Successfully activated changes" "success"
      fi
      success=true
      return 0
    elif [ "$status_code" = "422" ]; then
      if [ "$output_level" != "quiet" ]; then
        log "No changes to activate (all configurations already applied)" "warning"
      fi
      success=true
      return 0
    else
      if [ "$output_level" != "quiet" ]; then
        log "Activation warning (attempt $retry_count/$max_retries) - status code: $status_code" "warning"
      fi

      # Retry with delay
      retry_count=$((retry_count + 1))
      if [ $retry_count -le $max_retries ]; then
        sleep 3
      fi
    fi
  done

  if [ "$success" = false ] && [ "$output_level" != "quiet" ]; then
    log "Activation had issues after $max_retries attempts" "warning"
  fi

  return 0
}
