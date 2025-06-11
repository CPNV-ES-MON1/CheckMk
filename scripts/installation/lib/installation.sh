#!/bin/bash

# =============================================================================
# Title:        CheckMk Installation Module
# Description:  Functions for downloading, verifying and installing
#               the CheckMk monitoring software package
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-05-28
# Version:      1.0.1
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Verify package hash against expected value with enhanced logging
verify_package() {
  local actual_hash=$1
  local expected_hash=$2

  log "Verifying package integrity..." "info"
  log "Actual hash:   $actual_hash" "debug"
  log "Expected hash: $expected_hash" "debug"

  if [ "$actual_hash" != "$expected_hash" ]; then
    log "Package integrity verification failed!" "error"
    log "Expected: $expected_hash" "error"
    log "Actual:   $actual_hash" "error"
    log "This might indicate the package was corrupted during download or the config.json has the wrong hash." "error"
    log "Try deleting the package file and running the script again." "info"
    exit 1
  else
    log "Package integrity verified successfully" "success"
    return 0
  fi
}

# Download CheckMk package with enhanced progress reporting
download_checkmk() {
  log "Starting CheckMk package download process..." "info"
  log "Package file: $PACKAGE_FILE" "debug"
  log "Download URL: $DOWNLOAD_URL" "debug"

  if [ -f "$PACKAGE_FILE" ]; then
    log "Package file already exists, skipping download" "info"
    log "File size: $(du -h "$PACKAGE_FILE" | cut -f1)" "debug"
    log "File date: $(stat -c '%y' "$PACKAGE_FILE")" "debug"
  else
    log "Downloading file from $DOWNLOAD_URL" "info"
    log "This may take several minutes depending on your connection speed..." "info"

    if [ "$DEBUG_MODE" = true ]; then
      # Show download progress in debug mode
      if wget --progress=bar:force -q "$DOWNLOAD_URL" -O "$PACKAGE_FILE" 2>&1 | grep --line-buffered -o "[0-9]*%" | sed 's/\([0-9]*\)%/\1/'; then
        log "Package download complete" "success"
      else
        WGET_EXIT_CODE=$?
        log "Package download failed with exit code $WGET_EXIT_CODE" "error"
        log "URL: $DOWNLOAD_URL" "error"

        if [ $WGET_EXIT_CODE -eq 8 ]; then
          log "Status: 404 Not Found - The requested package could not be found on the server" "error"
          log "Version $CHECKMK_VERSION may not exist. Check https://checkmk.com/download for available versions." "info"
          log "Available CheckMk versions can be found at: https://checkmk.com/download?platform=cmk&distribution=ubuntu&release=jammy" "info"
        else
          log "Exit code: $WGET_EXIT_CODE" "error"
          log "Try running manually: wget -v \"$DOWNLOAD_URL\" for more information" "info"

          # Show common wget error codes and their meanings
          case $WGET_EXIT_CODE in
          1) log "Generic error" "debug" ;;
          2) log "Parse error in command line or config file" "debug" ;;
          3) log "File I/O error" "debug" ;;
          4) log "Network failure" "debug" ;;
          5) log "SSL verification failure" "debug" ;;
          6) log "Authentication failure" "debug" ;;
          7) log "Protocol error" "debug" ;;
          esac
        fi
        exit 1
      fi
    else
      # Simplified output for normal mode
      if wget -q "$DOWNLOAD_URL" -O "$PACKAGE_FILE"; then
        log "Package download complete" "success"
      else
        WGET_EXIT_CODE=$?
        log "Package download failed" "error"
        log "URL: $DOWNLOAD_URL" "error"

        if [ $WGET_EXIT_CODE -eq 8 ]; then
          log "Status: 404 Not Found" "error"
          log "Version $CHECKMK_VERSION may not exist. Check https://checkmk.com/download?platform=cmk&distribution=ubuntu&release=jammy" "info"
        else
          log "Exit code: $WGET_EXIT_CODE" "error"
          log "Try running: wget -v \"$DOWNLOAD_URL\" for more information" "info"
        fi
        exit 1
      fi
    fi

    log "Download completed, file size: $(du -h "$PACKAGE_FILE" | cut -f1)" "debug"
  fi

  # Verify package integrity
  log "Computing SHA256 hash of downloaded package..." "debug"
  ACTUAL_HASH=$(sha256sum "$PACKAGE_FILE" | awk '{print $1}')
  verify_package "$ACTUAL_HASH" "$EXPECTED_HASH"
}

# Install CheckMk package with enhanced logging
install_checkmk() {
  log "Starting CheckMk installation process..." "info"

  # System information before installation
  if [ "$DEBUG_MODE" = true ]; then
    log "System information before installation:" "debug"
    log "Free disk space: $(df -h / | awk 'NR==2 {print $4}')" "debug"
    log "Free memory: $(free -h | grep Mem | awk '{print $4}')" "debug"
    log "CPU load: $(uptime | awk -F'load average:' '{print $2}')" "debug"
  fi

  # Install CheckMk package
  execute_task "Installing CheckMk package (this may take several minutes)" "DEBIAN_FRONTEND=noninteractive apt install -y -q ./$PACKAGE_FILE" "true"

  # Verify installation success
  if command_exists omd; then
    INSTALLED_VERSION=$(omd version | grep -oP 'Version \K[^ ]+')
    log "CheckMk version $INSTALLED_VERSION installed successfully" "success"

    if [ "$DEBUG_MODE" = true ]; then
      log "Installation path: $(which omd)" "debug"
      log "Installed components:" "debug"
      omd version | while read -r line; do
        log "  $line" "debug"
      done
    fi
  else
    log "CheckMk installation failed - omd command not found in PATH" "error"
    log "This might be due to:" "error"
    log "  - Package installation failure" "error"
    log "  - PATH environment variable issues" "error"
    log "  - Dependency problems" "error"

    if [ "$DEBUG_MODE" = true ]; then
      log "Checking installation logs..." "debug"
      log "Last 10 lines of dpkg log:" "debug"
      tail -10 /var/log/dpkg.log | while read -r line; do
        log "  $line" "debug"
      done
    fi

    exit 1
  fi

  # System information after installation
  if [ "$DEBUG_MODE" = true ]; then
    log "System information after installation:" "debug"
    log "Free disk space: $(df -h / | awk 'NR==2 {print $4}')" "debug"
    log "Free memory: $(free -h | grep Mem | awk '{print $4}')" "debug"
    log "CPU load: $(uptime | awk -F'load average:' '{print $2}')" "debug"
  fi
}

# Fixed Install CheckMk Agent with enhanced version handling
install_checkmk_agent() {
  log "Starting CheckMk Agent installation process..." "info"

  # Get the exact installed version with any edition suffix (like 'cre')
  local exact_version=$(omd version | grep -oP 'Version \K[^ ]+')
  local base_version=$(echo "$exact_version" | cut -d'.' -f1,2,3) # Extract just X.Y.Z part

  log "Detected exact CheckMk version: $exact_version" "debug"
  log "Base version for agent: $base_version" "debug"

  # First check if we can list available agent packages
  log "Listing available agent packages..." "info"

  # Create a progress indicator for agent detection
  local i=0
  local sp="/-\|"
  printf "[$timestamp] [\033[34mINFO\033[0m] Detecting agent packages "

  # Fetch the agent directory listing
  local agents_html=$(curl -s "${API_BASE_URL}/${SITE_NAME}/check_mk/agents/")
  local found_agents=($(echo "$agents_html" | grep -o 'href="[^"]*\.deb"' | sed 's/href="//g;s/"//g'))

  printf "\r                                                    \r"

  if [ ${#found_agents[@]} -gt 0 ]; then
    log "Found ${#found_agents[@]} agent packages" "success"
    log "Available agent packages:" "debug"

    # Build list of possible agent filenames
    local agent_files=()

    for agent in "${found_agents[@]}"; do
      log "  $agent" "debug"
      if [[ "$agent" == *.deb ]]; then
        agent_files+=("$agent")
      fi
    done

    log "Using detected packages as primary options" "info"
  else
    log "No agent packages found via directory listing" "warning"

    # Default fallback filenames to try
    local agent_files=(
      "check-mk-agent_${base_version}-1_all.deb"  # Standard format with base version
      "check-mk-agent_${exact_version}-1_all.deb" # With exact version including edition
      "check-mk-agent.deb"                        # Generic filename
    )

    log "Will try these fallback agent filenames:" "debug"
    for f in "${agent_files[@]}"; do
      log "  $f" "debug"
    done
  fi

  # Try different agent URL locations
  local base_urls=(
    "${API_BASE_URL}/${SITE_NAME}/check_mk/agents/"
    "${API_BASE_URL}/${SITE_NAME}/agents/"
    "${API_BASE_URL}/${SITE_NAME}/check_mk/check_mk/agents/"
  )

  # This is the agent URL that works according to logs
  local known_working_url="${API_BASE_URL}/${SITE_NAME}/check_mk/agents/check-mk-agent_${base_version}-1_all.deb"

  log "Attempting known working URL first: $known_working_url" "debug"
  if curl --output /dev/null --silent --head --fail "$known_working_url"; then
    log "Found agent at known location: $known_working_url" "success"
    agent_url="$known_working_url"
    agent_file="check-mk-agent_${base_version}-1_all.deb"

    # Use a progress bar for the download
    log "Downloading agent package (with progress)..." "info"
    wget --progress=bar:force "$agent_url" -O "$agent_file" 2>&1 |
      while read -r line; do
        if [[ $line =~ ([0-9]+)% ]]; then
          percent="${BASH_REMATCH[1]}"
          num_chars=$((percent / 2))
          bar=$(printf "%${num_chars}s" | tr ' ' '#')
          printf "\r[$timestamp] [\033[34mINFO\033[0m] Progress: [%-50s] %3d%%" "$bar" "$percent"
        fi
      done
    printf "\n"

    if [ -f "$agent_file" ] && [ -s "$agent_file" ]; then
      log "Successfully downloaded agent package: $agent_file" "success"
      download_success=true
    else
      log "Failed to download from known location, trying alternatives" "warning"
      download_success=false
    fi
  else
    log "Known location not accessible, trying alternatives" "warning"
    download_success=false
  fi

  # Try each combination of URL and filename if the known URL didn't work
  if [ "$download_success" != true ]; then
    log "Trying alternative agent locations..." "info"

    # Initialize spinner for download attempts
    local sp_idx=0

    for base_url in "${base_urls[@]}"; do
      for file in "${agent_files[@]}"; do
        current_url="${base_url}${file}"

        # Update spinner
        printf "\r[$timestamp] [\033[34mINFO\033[0m] Trying: %s %c" "${file}" "${sp:sp_idx++%4:1}"

        # Check if URL exists before attempting download
        if curl --output /dev/null --silent --head --fail "$current_url"; then
          printf "\r                                                          \r"
          log "Found valid agent package URL: $current_url" "success"
          agent_file="$file"
          agent_url="$current_url"

          # Download the agent with progress
          log "Downloading agent package..." "info"
          wget --progress=bar:force "$agent_url" -O "$agent_file" 2>&1 |
            while read -r line; do
              if [[ $line =~ ([0-9]+)% ]]; then
                percent="${BASH_REMATCH[1]}"
                num_chars=$((percent / 2))
                bar=$(printf "%${num_chars}s" | tr ' ' '#')
                printf "\r[$timestamp] [\033[34mINFO\033[0m] Progress: [%-50s] %3d%%" "$bar" "$percent"
              fi
            done
          printf "\n"

          if [ -f "$agent_file" ] && [ -s "$agent_file" ]; then
            log "Successfully downloaded agent package: $agent_file" "success"
            download_success=true
            break 2 # Break out of both loops
          else
            log "Download failed for URL: $agent_url" "warning"
          fi
        fi
      done
    done
    printf "\r                                                          \r"
  fi

  if [ "$download_success" != true ]; then
    log "Failed to download agent package from any location" "error"
    log "Please download the agent package manually from the CheckMk web interface:" "info"
    log "1. Go to http://localhost/${SITE_NAME}/" "info"
    log "2. Login with username: cmkadmin, password: $SITE_PASSWORD" "info"
    log "3. Navigate to Setup -> Agents -> Linux" "info"
    log "4. Download the .deb package and install it manually" "info"
    return 1
  fi

  # Verify agent package exists and has content
  if [ ! -s "$agent_file" ]; then
    log "Agent package is empty or missing" "error"
    return 1
  fi

  log "Agent package size: $(du -h "$agent_file" | cut -f1)" "debug"

  # Install the agent with spinner
  log "Installing CheckMk agent..." "info"

  # Run installation in background with spinner
  DEBIAN_FRONTEND=noninteractive apt install -y -q ./$agent_file >/tmp/agent_install.log 2>&1 &
  local install_pid=$!

  # Show spinner while installation is running
  local sp_chars='/-\|'
  while ps -p $install_pid >/dev/null; do
    for ((i = 0; i < ${#sp_chars}; i++)); do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Installing agent... %c" "${sp_chars:$i:1}"
      sleep 0.2
    done
  done
  printf "\r                                             \r"

  # Check if installation succeeded
  wait $install_pid
  if [ $? -eq 0 ]; then
    log "CheckMk agent installed successfully" "success"
  else
    log "Agent installation failed" "error"
    cat /tmp/agent_install.log | while read -r line; do
      log "  $line" "error"
    done
    return 1
  fi

  # Configure agent to start with spinner
  log "Enabling CheckMk agent service..." "info"
  systemctl enable check_mk_agent.socket >/tmp/agent_enable.log 2>&1 &
  local enable_pid=$!

  # Show spinner for service enabling
  while ps -p $enable_pid >/dev/null; do
    for ((i = 0; i < ${#sp_chars}; i++)); do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Enabling agent service... %c" "${sp_chars:$i:1}"
      sleep 0.2
    done
  done
  printf "\r                                                \r"

  log "Starting CheckMk agent service..." "info"
  systemctl start check_mk_agent.socket >/tmp/agent_start.log 2>&1 &
  local start_pid=$!

  # Show spinner for service starting
  while ps -p $start_pid >/dev/null; do
    for ((i = 0; i < ${#sp_chars}; i++)); do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Starting agent service... %c" "${sp_chars:$i:1}"
      sleep 0.2
    done
  done
  printf "\r                                               \r"

  # Verify agent is running
  local agent_status=$(systemctl is-active check_mk_agent.socket)
  if [ "$agent_status" = "active" ]; then
    log "CheckMk agent service is active" "success"
  else
    log "CheckMk agent service is not active (status: $agent_status)" "warning"
    log "You may need to start it manually: sudo systemctl start check_mk_agent.socket" "info"
  fi

  # Show agent port status
  log "Checking agent port (6556):" "debug"
  ss -tuln | grep 6556 | while read -r line; do
    log "  $line" "debug"
  done

  log "CheckMk agent installation completed" "success"
}

# Update system packages with improved error handling, timeouts, and visual progress
update_system_packages() {
  log "Updating system packages..." "info"

  # Just update package lists first - this is usually quick
  log "Updating package lists..." "info"
  if ! execute_task "Updating package lists" "apt update -qq"; then
    log "Warning: Package update failed, but we'll continue anyway" "warning"
    # Continue even if update fails
  fi

  # Check for upgradable packages
  log "Checking for upgradable packages..." "info"
  # Fix command to be more reliable and redirect stderr to avoid polluting output
  local upgradable_count=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
  log "Found $upgradable_count upgradable packages" "info"

  if [ "$upgradable_count" = "0" ]; then
    log "No packages need upgrading, skipping upgrade step" "info"
    return 0
  fi

  # Simplify the upgrade command to avoid quoting issues
  # Store the complex options in a temporary file
  cat >/tmp/apt-upgrade-options <<EOF
Dpkg::Options::="--force-confdef";
Dpkg::Options::="--force-confold";
EOF

  # Use the simplified command with the options file
  local upgrade_cmd="DEBIAN_FRONTEND=noninteractive apt-get -o Dir::Etc::OptionsParts=\"/tmp/apt-upgrade-options\" upgrade -y -qq"

  # Show a spinner for the upgrade process (10 minute timeout)
  # Don't log the message separately - the spinner will show it
  if execute_with_spinner "Upgrading packages" "$upgrade_cmd" 600; then
    # Success message will be shown by execute_with_spinner
    :
  else
    log "Package upgrade failed or timed out, continuing anyway" "warning"
    log "You may need to run 'apt upgrade' manually after installation" "info"
    # Continue even if upgrade fails
  fi

  # Clean up
  rm -f /tmp/apt-upgrade-options

  return 0
}

# Download CheckMk package with better progress indicator
download_checkmk_package() {
  log "Preparing to download CheckMk package..." "info"

  # Set package file name and download URL based on configuration
  PACKAGE_FILE="${PACKAGE_PREFIX}-${CHECKMK_VERSION}_0.${UBUNTU_CODENAME}_amd64.deb"
  DOWNLOAD_URL=$(printf "$DOWNLOAD_URL_TEMPLATE" "$CHECKMK_VERSION" "$PACKAGE_FILE")

  if [ -f "$PACKAGE_FILE" ]; then
    log "Package file already exists" "info"
  else
    # Don't log "Downloading..." message here - the spinner will show it
    if execute_with_spinner "Downloading CheckMk package" "wget --quiet \"$DOWNLOAD_URL\" -O \"$PACKAGE_FILE\"" 1800; then
      log "File size: $(du -h "$PACKAGE_FILE" | cut -f1)" "info"
    else
      log "Package download failed" "error"
      log "URL: $DOWNLOAD_URL" "error"
      log "Try running: wget -v \"$DOWNLOAD_URL\" for more information" "info"
      exit 1
    fi
  fi

  # Verify package integrity with spinner - don't log separate message
  execute_with_spinner "Verifying package integrity" "sha256sum \"$PACKAGE_FILE\" > /tmp/hash_result.txt" 300
  ACTUAL_HASH=$(cat /tmp/hash_result.txt | awk '{print $1}')
  rm -f /tmp/hash_result.txt

  verify_package "$ACTUAL_HASH" "$EXPECTED_HASH"
}

# Install CheckMk with improved progress indicator
install_checkmk() {
  log "Starting CheckMk installation process..." "info"

  # System information before installation
  if [ "$DEBUG_MODE" = true ]; then
    log "System information before installation:" "debug"
    log "Free disk space: $(df -h / | awk 'NR==2 {print $4}')" "debug"
    log "Free memory: $(free -h | grep Mem | awk '{print $4}')" "debug"
    log "CPU load: $(uptime | awk -F'load average:' '{print $2}')" "debug"
  fi

  # Install CheckMk package with spinner for better progress visualization - 20 minute timeout
  execute_with_spinner "Installing CheckMk package" "DEBIAN_FRONTEND=noninteractive apt install -y -q ./$PACKAGE_FILE" 1200

  # Verify installation success
  if command_exists omd; then
    INSTALLED_VERSION=$(omd version | grep -oP 'Version \K[^ ]+')
    log "CheckMk version $INSTALLED_VERSION installed successfully" "success"

    if [ "$DEBUG_MODE" = true ]; then
      log "Installation path: $(which omd)" "debug"
      log "Installed components:" "debug"
      omd version | while read -r line; do
        log "  $line" "debug"
      done
    fi
  else
    log "CheckMk installation failed - omd command not found in PATH" "error"
    log "This might be due to:" "error"
    log "  - Package installation failure" "error"
    log "  - PATH environment variable issues" "error"
    log "  - Dependency problems" "error"

    if [ "$DEBUG_MODE" = true ]; then
      log "Checking installation logs..." "debug"
      log "Last 10 lines of dpkg log:" "debug"
      tail -10 /var/log/dpkg.log | while read -r line; do
        log "  $line" "debug"
      done
    fi

    exit 1
  fi

  # System information after installation
  if [ "$DEBUG_MODE" = true ]; then
    log "System information after installation:" "debug"
    log "Free disk space: $(df -h / | awk 'NR==2 {print $4}')" "debug"
    log "Free memory: $(free -h | grep Mem | awk '{print $4}')" "debug"
    log "CPU load: $(uptime | awk -F'load average:' '{print $2}')" "debug"
  fi
}

# Fixed Install CheckMk Agent with enhanced version handling
install_checkmk_agent() {
  log "Starting CheckMk Agent installation process..." "info"

  # Get the exact installed version with any edition suffix (like 'cre')
  local exact_version=$(omd version | grep -oP 'Version \K[^ ]+')
  local base_version=$(echo "$exact_version" | cut -d'.' -f1,2,3) # Extract just X.Y.Z part

  log "Detected exact CheckMk version: $exact_version" "debug"
  log "Base version for agent: $base_version" "debug"

  # First check if we can list available agent packages
  log "Listing available agent packages..." "info"

  # Create a progress indicator for agent detection
  local i=0
  local sp="/-\|"
  printf "[$timestamp] [\033[34mINFO\033[0m] Detecting agent packages "

  # Fetch the agent directory listing
  local agents_html=$(curl -s "${API_BASE_URL}/${SITE_NAME}/check_mk/agents/")
  local found_agents=($(echo "$agents_html" | grep -o 'href="[^"]*\.deb"' | sed 's/href="//g;s/"//g'))

  printf "\r                                                    \r"

  if [ ${#found_agents[@]} -gt 0 ]; then
    log "Found ${#found_agents[@]} agent packages" "success"
    log "Available agent packages:" "debug"

    # Build list of possible agent filenames
    local agent_files=()

    for agent in "${found_agents[@]}"; do
      log "  $agent" "debug"
      if [[ "$agent" == *.deb ]]; then
        agent_files+=("$agent")
      fi
    done

    log "Using detected packages as primary options" "info"
  else
    log "No agent packages found via directory listing" "warning"

    # Default fallback filenames to try
    local agent_files=(
      "check-mk-agent_${base_version}-1_all.deb"  # Standard format with base version
      "check-mk-agent_${exact_version}-1_all.deb" # With exact version including edition
      "check-mk-agent.deb"                        # Generic filename
    )

    log "Will try these fallback agent filenames:" "debug"
    for f in "${agent_files[@]}"; do
      log "  $f" "debug"
    done
  fi

  # Try different agent URL locations
  local base_urls=(
    "${API_BASE_URL}/${SITE_NAME}/check_mk/agents/"
    "${API_BASE_URL}/${SITE_NAME}/agents/"
    "${API_BASE_URL}/${SITE_NAME}/check_mk/check_mk/agents/"
  )

  # This is the agent URL that works according to logs
  local known_working_url="${API_BASE_URL}/${SITE_NAME}/check_mk/agents/check-mk-agent_${base_version}-1_all.deb"

  log "Attempting known working URL first: $known_working_url" "debug"
  if curl --output /dev/null --silent --head --fail "$known_working_url"; then
    log "Found agent at known location: $known_working_url" "success"
    agent_url="$known_working_url"
    agent_file="check-mk-agent_${base_version}-1_all.deb"

    # Use a progress bar for the download
    log "Downloading agent package (with progress)..." "info"
    wget --progress=bar:force "$agent_url" -O "$agent_file" 2>&1 |
      while read -r line; do
        if [[ $line =~ ([0-9]+)% ]]; then
          percent="${BASH_REMATCH[1]}"
          num_chars=$((percent / 2))
          bar=$(printf "%${num_chars}s" | tr ' ' '#')
          printf "\r[$timestamp] [\033[34mINFO\033[0m] Progress: [%-50s] %3d%%" "$bar" "$percent"
        fi
      done
    printf "\n"

    if [ -f "$agent_file" ] && [ -s "$agent_file" ]; then
      log "Successfully downloaded agent package: $agent_file" "success"
      download_success=true
    else
      log "Failed to download from known location, trying alternatives" "warning"
      download_success=false
    fi
  else
    log "Known location not accessible, trying alternatives" "warning"
    download_success=false
  fi

  # Try each combination of URL and filename if the known URL didn't work
  if [ "$download_success" != true ]; then
    log "Trying alternative agent locations..." "info"

    # Initialize spinner for download attempts
    local sp_idx=0

    for base_url in "${base_urls[@]}"; do
      for file in "${agent_files[@]}"; do
        current_url="${base_url}${file}"

        # Update spinner
        printf "\r[$timestamp] [\033[34mINFO\033[0m] Trying: %s %c" "${file}" "${sp:sp_idx++%4:1}"

        # Check if URL exists before attempting download
        if curl --output /dev/null --silent --head --fail "$current_url"; then
          printf "\r                                                          \r"
          log "Found valid agent package URL: $current_url" "success"
          agent_file="$file"
          agent_url="$current_url"

          # Download the agent with progress
          log "Downloading agent package..." "info"
          wget --progress=bar:force "$agent_url" -O "$agent_file" 2>&1 |
            while read -r line; do
              if [[ $line =~ ([0-9]+)% ]]; then
                percent="${BASH_REMATCH[1]}"
                num_chars=$((percent / 2))
                bar=$(printf "%${num_chars}s" | tr ' ' '#')
                printf "\r[$timestamp] [\033[34mINFO\033[0m] Progress: [%-50s] %3d%%" "$bar" "$percent"
              fi
            done
          printf "\n"

          if [ -f "$agent_file" ] && [ -s "$agent_file" ]; then
            log "Successfully downloaded agent package: $agent_file" "success"
            download_success=true
            break 2 # Break out of both loops
          else
            log "Download failed for URL: $agent_url" "warning"
          fi
        fi
      done
    done
    printf "\r                                                          \r"
  fi

  if [ "$download_success" != true ]; then
    log "Failed to download agent package from any location" "error"
    log "Please download the agent package manually from the CheckMk web interface:" "info"
    log "1. Go to http://localhost/${SITE_NAME}/" "info"
    log "2. Login with username: cmkadmin, password: $SITE_PASSWORD" "info"
    log "3. Navigate to Setup -> Agents -> Linux" "info"
    log "4. Download the .deb package and install it manually" "info"
    return 1
  fi

  # Verify agent package exists and has content
  if [ ! -s "$agent_file" ]; then
    log "Agent package is empty or missing" "error"
    return 1
  fi

  log "Agent package size: $(du -h "$agent_file" | cut -f1)" "debug"

  # Install the agent with spinner
  log "Installing CheckMk agent..." "info"

  # Run installation in background with spinner
  DEBIAN_FRONTEND=noninteractive apt install -y -q ./$agent_file >/tmp/agent_install.log 2>&1 &
  local install_pid=$!

  # Show spinner while installation is running
  local sp_chars='/-\|'
  while ps -p $install_pid >/dev/null; do
    for ((i = 0; i < ${#sp_chars}; i++)); do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Installing agent... %c" "${sp_chars:$i:1}"
      sleep 0.2
    done
  done
  printf "\r                                             \r"

  # Check if installation succeeded
  wait $install_pid
  if [ $? -eq 0 ]; then
    log "CheckMk agent installed successfully" "success"
  else
    log "Agent installation failed" "error"
    cat /tmp/agent_install.log | while read -r line; do
      log "  $line" "error"
    done
    return 1
  fi

  # Configure agent to start with spinner
  log "Enabling CheckMk agent service..." "info"
  systemctl enable check_mk_agent.socket >/tmp/agent_enable.log 2>&1 &
  local enable_pid=$!

  # Show spinner for service enabling
  while ps -p $enable_pid >/dev/null; do
    for ((i = 0; i < ${#sp_chars}; i++)); do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Enabling agent service... %c" "${sp_chars:$i:1}"
      sleep 0.2
    done
  done
  printf "\r                                                \r"

  log "Starting CheckMk agent service..." "info"
  systemctl start check_mk_agent.socket >/tmp/agent_start.log 2>&1 &
  local start_pid=$!

  # Show spinner for service starting
  while ps -p $start_pid >/dev/null; do
    for ((i = 0; i < ${#sp_chars}; i++)); do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Starting agent service... %c" "${sp_chars:$i:1}"
      sleep 0.2
    done
  done
  printf "\r                                               \r"

  # Verify agent is running
  local agent_status=$(systemctl is-active check_mk_agent.socket)
  if [ "$agent_status" = "active" ]; then
    log "CheckMk agent service is active" "success"
  else
    log "CheckMk agent service is not active (status: $agent_status)" "warning"
    log "You may need to start it manually: sudo systemctl start check_mk_agent.socket" "info"
  fi

  # Show agent port status
  log "Checking agent port (6556):" "debug"
  ss -tuln | grep 6556 | while read -r line; do
    log "  $line" "debug"
  done

  log "CheckMk agent installation completed" "success"
}
