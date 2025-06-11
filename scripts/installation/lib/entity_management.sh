#!/bin/bash

# =============================================================================
# Title:        CheckMk Entity Management Module
# Description:  Functions for managing CheckMk monitoring entities
#               Handles folders, hosts, and other monitoring objects
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-05-28
# Version:      1.0.0
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Check if a host already exists
host_exists() {
  local hostname=$1
  local site_name=$2

  log "Checking if host '$hostname' already exists..." "debug"

  local response=$(curl --silent \
    --request GET \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    --write-out "%{http_code}" \
    --output /tmp/host_check.json \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/objects/host_config/$hostname")

  local http_code=$response

  if [ "$http_code" = "200" ]; then
    log "Host '$hostname' already exists in CheckMk" "debug"
    return 0 # Host exists
  else
    log "Host '$hostname' does not exist in CheckMk (HTTP code: $http_code)" "debug"
    return 1 # Host doesn't exist
  fi
}

# Check if folder exists in CheckMk using the correct API endpoint
check_folder_exists_in_checkmk() {
  local folder_name=$1
  local site_name=$2
  local cache_file="/tmp/folder_cache_${site_name}.txt"

  # Check cache first if it exists
  if [ -f "$cache_file" ] && grep -q "^${folder_name}$" "$cache_file"; then
    log "Folder '$folder_name' exists (from cache)" "debug"
    return 0
  fi

  log "Checking if folder '$folder_name' exists in CheckMk..." "debug"

  # Use proper REST API path format - folders in CheckMk API often use ~ prefix
  local encoded_folder="~${folder_name}"
  local response=$(curl --silent \
    --request GET \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    --write-out "%{http_code}" \
    --output /tmp/folder_check.json \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/objects/folder_config/${encoded_folder}")

  if [ "$response" = "200" ]; then
    log "Folder '$folder_name' exists (using ~prefix notation)" "debug"
    # Cache result for future checks
    echo "$folder_name" >>"$cache_file"
    return 0
  fi

  # Try alternate approaches for compatibility
  # Check all folders listing with grep
  local all_folders=$(curl --silent \
    --request GET \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/folder_config/collections/all" |
    grep -o "\"id\":\"[^\"]*\"" | cut -d'"' -f4)

  # Check if folder exists in the list
  if echo "$all_folders" | grep -q "^${folder_name}$" || echo "$all_folders" | grep -q "^~${folder_name}$"; then
    log "Folder '$folder_name' found in folder listing" "debug"
    # Cache result for future checks
    echo "$folder_name" >>"$cache_file"
    return 0
  fi

  log "Folder '$folder_name' does not exist in CheckMk" "debug"
  return 1
}

create_folder() {
  local folder_name=$1
  local folder_title=$2
  local parent="/"
  local site_name=$3

  # Check if folder already exists before trying to create it
  if check_folder_exists_in_checkmk "$folder_name" "$site_name"; then
    log "Folder '$folder_name' already exists in CheckMk, skipping creation" "info"
    return 0
  fi

  log "Creating folder '$folder_name' in CheckMk" "info"

  # Create folder with simplified payload
  local response=$(curl --silent \
    --request POST \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --data "{\"name\":\"$folder_name\",\"title\":\"$folder_title\",\"parent\":\"$parent\"}" \
    --write-out "\n%{http_code}" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/folder_config/collections/all")

  local status_code=$(echo "$response" | tail -n1)
  local response_body=$(echo "$response" | sed '$d')

  if [ "$status_code" = "200" ] || [ "$status_code" = "204" ] || [ "$status_code" = "201" ]; then
    log "Successfully created folder '$folder_name'" "success"

    # Add to folder cache immediately
    echo "$folder_name" >>"/tmp/folder_cache_${site_name}.txt"

    # Wait just once with a longer timeout
    log "Waiting for folder to be registered in the system..." "debug"
    sleep 3

    # Trigger activation after folder creation to ensure it's available
    local activate_response=$(curl --silent \
      --request POST \
      --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
      --header "Content-Type: application/json" \
      --data "{\"force_foreign_changes\":true}" \
      "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/activation_run/actions/activate-changes/invoke")

    # Consider folder created successfully regardless of verification
    return 0
  else
    log "Failed to create folder '$folder_name'" "error"
    log "Status code: $status_code" "error"
    log "Response: $response_body" "error"
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

  # First check if host already exists
  if host_exists "$hostname" "$site_name"; then
    log "Host '$hostname' already exists, skipping..." "info"
    return 0
  fi

  # Check if folder exists in CheckMk with retry logic
  local folder_check_retries=3
  local folder_exists=false

  for ((i = 1; i <= $folder_check_retries; i++)); do
    if check_folder_exists_in_checkmk "$folder_name" "$site_name"; then
      folder_exists=true
      break
    else
      log "Folder check attempt $i failed, retrying..." "debug"
      sleep 2
    fi
  done

  if [ "$folder_exists" = false ]; then
    # If folder doesn't exist after retries, attempt to create it
    log "Folder '$folder_name' not found in CheckMk after $folder_check_retries attempts" "warning"
    log "Attempting to create the folder now..." "info"

    local folder_title=$(get_folder_title "$folder_name" "Auto-created folder")
    if create_folder "$folder_name" "$folder_title" "$site_name"; then
      log "Successfully created missing folder '$folder_name'" "success"
      # Allow some time for folder to be registered
      sleep 3
    else
      log "Error: Failed to create folder '$folder_name', cannot add host '$hostname'" "error"
      return 1
    fi
  fi

  log "Adding host '$hostname' to folder '$folder_name'" "info"

  # Prepare the request payload
  local payload="{\"host_name\":\"$hostname\",\"folder\":\"/$folder_name\",\"attributes\":{\"ipaddress\":\"$ipaddress\"}}"
  log "API request payload: $payload" "debug"

  # Make the API request and save the full response
  local full_response=$(curl --silent \
    --request POST \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --data "$payload" \
    --write-out "\n%{http_code}" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/host_config/collections/all?bake_agent=false")

  local status_code=$(echo "$full_response" | tail -n1)
  local response_body=$(echo "$full_response" | sed '$d')

  log "API status code: $status_code" "debug"
  log "API response: $response_body" "debug"

  # Check if response indicates success (status code 200-299)
  if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]] && [[ "$response_body" == *"id"* ]]; then
    log "Successfully added host '$hostname'" "success"

    # Double-check host existence after adding
    if host_exists "$hostname" "$site_name"; then
      log "Verified host '$hostname' now exists in CheckMk" "success"
      return 0
    else
      log "Warning: Host addition API succeeded but host not found on verification check" "warning"
      # Continue anyway since API reported success
      return 0
    fi
  else
    log "Failed to add host '$hostname'" "error"
    log "API status code: $status_code" "error"
    log "API response: $response_body" "error"

    # Try to decode the error for better troubleshooting
    if [[ "$response_body" == *"error"* ]] || [[ "$response_body" == *"detail"* ]]; then
      if command_exists jq && echo "$response_body" | jq . &>/dev/null; then
        local error_detail=$(echo "$response_body" | jq -r '.detail // .error // "Unknown error"')
        log "Error details: $error_detail" "error"
      fi
    fi

    return 1
  fi
}

# Optimized function to create folders with minimal API calls
create_folders_from_config() {
  log "Creating folders from configuration..." "info"

  # Clear folder cache
  rm -f "/tmp/folder_cache_${SITE_NAME}.txt" 2>/dev/null

  # Create all folders at once
  local folders_json="["
  local i=0
  local total_folders=${#FOLDERS[@]}

  for folder in "${FOLDERS[@]}"; do
    folder_name="${folder%%|*}"
    folder_title="${folder#*|}"

    # Add to JSON array
    folders_json+="{\"name\":\"$folder_name\",\"title\":\"$folder_title\",\"parent\":\"/\"}"

    # Add comma if not the last item
    i=$((i + 1))
    if [ $i -lt $total_folders ]; then
      folders_json+=","
    fi
  done

  folders_json+="]"

  # First try batch creation if supported
  local batch_response=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --request POST \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Content-Type: application/json" \
    --data "{\"entries\":$folders_json}" \
    "${API_BASE_URL}/${SITE_NAME}/check_mk/api/1.0/domain-types/folder_config/actions/bulk-create/invoke")

  if [ "$batch_response" = "200" ] || [ "$batch_response" = "207" ]; then
    log "Batch creation of folders successful" "success"
    sleep 3 # Wait for changes to propagate
  else
    # Fall back to individual creation
    log "Batch creation not supported, creating folders individually" "info"
    for folder in "${FOLDERS[@]}"; do
      folder_name="${folder%%|*}"
      folder_title="${folder#*|}"
      create_folder "$folder_name" "$folder_title" "$SITE_NAME"
    done
  fi

  # Always activate changes after creating folders
  force_activation "$SITE_NAME" >/dev/null

  # Wait for changes to be applied
  log "Waiting for folder changes to be processed..." "info"
  sleep 5

  log "Folder creation completed" "success"
}

# Optimized host addition with better error handling
add_hosts_from_config() {
  local site_name=$1
  local attempted=0
  local successful=0
  local skipped=0
  local failed=0

  if [ -f "$CONFIG_FILE" ] && command_exists jq; then
    log "Adding hosts from configuration file" "info"

    # Extract hosts into an array for more efficient processing
    local host_count=$(jq '.hosts | length' "$CONFIG_FILE")
    log "Processing $host_count hosts from configuration" "info"

    # Process each host
    jq -c '.hosts[]' "$CONFIG_FILE" 2>/dev/null | while read -r host; do
      local hostname=$(echo "$host" | jq -r '.hostname')
      local ipaddress=$(echo "$host" | jq -r '.ipaddress')
      local folder=$(echo "$host" | jq -r '.folder')

      attempted=$((attempted + 1))

      if [ -z "$hostname" ] || [ -z "$folder" ]; then
        log "Skipping host with missing hostname or folder" "warning"
        skipped=$((skipped + 1))
        continue
      fi

      if ! folder_exists "$folder"; then
        log "Folder '$folder' not found in configuration, skipping host '$hostname'" "warning"
        skipped=$((skipped + 1))
        continue
      fi

      # Check if host already exists
      if host_exists "$hostname" "$site_name"; then
        log "Host '$hostname' already exists, skipping..." "info"
        skipped=$((skipped + 1))
        continue
      fi

      # Add the host - folder existence is checked inside add_host
      if add_host "$hostname" "$ipaddress" "$folder" "$site_name"; then
        successful=$((successful + 1))
      else
        failed=$((failed + 1))
      fi
    done
  else
    log "No configuration file with hosts found or jq not installed" "warning"
    return 1
  fi

  # Report statistics
  log "Host addition completed: $successful added, $skipped skipped, $failed failed" "info"

  # Return success if we either successfully added hosts or skipped all
  if [ $successful -gt 0 ] || [ $skipped -eq $attempted ]; then
    return 0
  else
    return 1
  fi
}
