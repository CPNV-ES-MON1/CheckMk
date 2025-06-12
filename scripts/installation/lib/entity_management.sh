#!/bin/bash

# =============================================================================
# CheckMk Entity Management Module
# Functions for managing folders, hosts, and monitoring objects
# =============================================================================

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
    return 0
  else
    log "Host '$hostname' does not exist in CheckMk (HTTP code: $http_code)" "debug"
    return 1
  fi
}

check_folder_exists_in_checkmk() {
  local folder_name=$1
  local site_name=$2
  local cache_file="/tmp/folder_cache_${site_name}.txt"

  # Use local cache to reduce API calls
  if [ -f "$cache_file" ] && grep -q "^${folder_name}$" "$cache_file"; then
    log "Folder '$folder_name' exists (from cache)" "debug"
    return 0
  fi

  log "Checking if folder '$folder_name' exists in CheckMk..." "debug"

  # CheckMk API uses ~ prefix for folder paths
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
    echo "$folder_name" >>"$cache_file"
    return 0
  fi

  # Fallback: search in complete folder listing
  local all_folders=$(curl --silent \
    --request GET \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/folder_config/collections/all" |
    grep -o "\"id\":\"[^\"]*\"" | cut -d'"' -f4)

  if echo "$all_folders" | grep -q "^${folder_name}$" || echo "$all_folders" | grep -q "^~${folder_name}$"; then
    log "Folder '$folder_name' found in folder listing" "debug"
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

  if check_folder_exists_in_checkmk "$folder_name" "$site_name"; then
    log "Folder '$folder_name' already exists in CheckMk, skipping creation" "info"
    return 0
  fi

  log "Creating folder '$folder_name' in CheckMk" "info"

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

    echo "$folder_name" >>"/tmp/folder_cache_${site_name}.txt"

    log "Waiting for folder to be registered in the system..." "debug"
    sleep 3

    # Activate changes to ensure folder is available
    local activate_response=$(curl --silent \
      --request POST \
      --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
      --header "Content-Type: application/json" \
      --data "{\"force_foreign_changes\":true}" \
      "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/activation_run/actions/activate-changes/invoke")

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
  local max_retries=5
  local retry_count=1

  if ! folder_exists "$folder"; then
    log "Folder '$folder' not defined in configuration, skipping host '$hostname'" "warning"
    return 0
  fi

  local folder_name="${folder%%|*}"

  if host_exists "$hostname" "$site_name"; then
    log "Host '$hostname' already exists, skipping..." "info"
    return 0
  fi

  # Verify folder exists in CheckMk
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
    # Create missing folder
    log "Folder '$folder_name' not found in CheckMk after $folder_check_retries attempts" "warning"
    log "Attempting to create the folder now..." "info"

    local folder_title=$(get_folder_title "$folder_name" "Auto-created folder")
    if create_folder "$folder_name" "$folder_title" "$site_name"; then
      log "Successfully created missing folder '$folder_name'" "success"
      sleep 3
    else
      log "Error: Failed to create folder '$folder_name', cannot add host '$hostname'" "error"
      return 1
    fi
  fi

  while [ $retry_count -le $max_retries ]; do
    log "Adding host '$hostname' to folder '$folder_name' (attempt $retry_count/$max_retries)" "info"

    local payload="{\"host_name\":\"$hostname\",\"folder\":\"/$folder_name\",\"attributes\":{\"ipaddress\":\"$ipaddress\"}}"
    log "API request payload: $payload" "debug"

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

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
      log "Successfully added host '$hostname'" "success"

      # Verify host was actually created
      local verify_retries=3
      local host_verified=false

      for ((i = 1; i <= $verify_retries; i++)); do
        if host_exists "$hostname" "$site_name"; then
          log "Verified host '$hostname' now exists in CheckMk (verification attempt $i)" "success"
          host_verified=true
          break
        else
          log "Host verification attempt $i failed, waiting before retry..." "debug"
          sleep 2
        fi
      done

      if [ "$host_verified" = true ]; then
        return 0
      else
        log "Warning: Host addition API succeeded but host not found on verification" "warning"
        retry_count=$((retry_count + 1))
        sleep 3
      fi
    elif [[ "$status_code" -eq 409 ]]; then
      # 409 Conflict typically means the host already exists
      log "Host '$hostname' appears to already exist (conflict) - marking as success" "warning"
      return 0
    else
      log "Failed to add host '$hostname' (attempt $retry_count/$max_retries)" "error"
      log "API status code: $status_code" "error"
      log "API response: $response_body" "error"

      if [[ "$response_body" == *"error"* ]] || [[ "$response_body" == *"detail"* ]]; then
        if command_exists jq && echo "$response_body" | jq . &>/dev/null; then
          local error_detail=$(echo "$response_body" | jq -r '.detail // .error // "Unknown error"')
          log "Error details: $error_detail" "error"
        fi
      fi

      retry_count=$((retry_count + 1))
      sleep 3
    fi
  done

  log "Failed to add host '$hostname' after $max_retries attempts" "error"
  return 1
}

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

    folders_json+="{\"name\":\"$folder_name\",\"title\":\"$folder_title\",\"parent\":\"/\"}"

    i=$((i + 1))
    if [ $i -lt $total_folders ]; then
      folders_json+=","
    fi
  done

  folders_json+="]"

  # Try batch creation first (more efficient)
  local batch_response=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --request POST \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Content-Type: application/json" \
    --data "{\"entries\":$folders_json}" \
    "${API_BASE_URL}/${SITE_NAME}/check_mk/api/1.0/domain-types/folder_config/actions/bulk-create/invoke")

  if [ "$batch_response" = "200" ] || [ "$batch_response" = "207" ]; then
    log "Batch creation of folders successful" "success"
    sleep 3
  else
    # Fall back to individual creation
    log "Batch creation not supported, creating folders individually" "info"
    for folder in "${FOLDERS[@]}"; do
      folder_name="${folder%%|*}"
      folder_title="${folder#*|}"
      create_folder "$folder_name" "$folder_title" "$SITE_NAME"
    done
  fi

  # Apply changes
  force_activation "$SITE_NAME" >/dev/null

  log "Waiting for folder changes to be processed..." "info"
  sleep 5

  log "Folder creation completed" "success"
}

add_hosts_from_config() {
  local site_name=$1
  local attempted=0
  local successful=0
  local skipped=0
  local failed=0
  local total_hosts=0

  if [ -f "$CONFIG_FILE" ] && command_exists jq; then
    total_hosts=$(jq '.hosts | length' "$CONFIG_FILE")
    log "Adding $total_hosts hosts from configuration file" "info"

    jq -c '.hosts[]' "$CONFIG_FILE" 2>/dev/null | while read -r host; do
      local hostname=$(echo "$host" | jq -r '.hostname')
      local ipaddress=$(echo "$host" | jq -r '.ipaddress')
      local folder=$(echo "$host" | jq -r '.folder')

      attempted=$((attempted + 1))
      log "Processing host $attempted/$total_hosts: $hostname" "info"

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

      if add_host "$hostname" "$ipaddress" "$folder" "$site_name"; then
        successful=$((successful + 1))
      else
        failed=$((failed + 1))
      fi
    done

    log "Host addition completed: $successful added, $skipped skipped, $failed failed" "info"

    log "Activating changes to apply host additions..." "info"
    force_activation "$site_name" "quiet"

    if [ $successful -gt 0 ] || [ $skipped -eq $attempted ]; then
      return 0
    elif [ $attempted -eq 0 ]; then
      log "No hosts were found in configuration to add" "warning"
      return 0
    else
      return 1
    fi
  else
    log "No configuration file with hosts found or jq not installed" "warning"
    return 1
  fi
}
