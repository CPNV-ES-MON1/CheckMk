#!/bin/bash

# =============================================================================
# Title:        CheckMk Configuration Loader Module
# Description:  Functions for loading and validating configuration data
#               from JSON configuration files
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-05-28
# Version:      1.0.0
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Check for configuration files
check_config_files() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log "Configuration file not found: $CONFIG_FILE" "error"
    exit 1
  fi
}

# Load configuration from JSON file
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    log "Loading configuration from $CONFIG_FILE" "info"
    if command_exists jq; then
      # Validate JSON format
      if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log "Invalid JSON format in $CONFIG_FILE" "error"
        log "Please check the file format and ensure it starts with '{' and ends with '}'" "info"
        exit 1
      fi

      # Extract all configuration
      SITE_NAME=$(jq -r '.site_name' "$CONFIG_FILE")
      CHECKMK_VERSION=$(jq -r '.checkmk_version' "$CONFIG_FILE")
      EXPECTED_HASH=$(jq -r '.expected_hash' "$CONFIG_FILE")

      # Extract API settings with defaults
      API_HOST=$(jq -r '.api_settings.host // "localhost"' "$CONFIG_FILE")
      API_PORT=$(jq -r '.api_settings.port // 80' "$CONFIG_FILE")

      log "API settings: Host=$API_HOST, Port=$API_PORT" "debug"

      log "Loading folders from configuration" "debug"
      readarray -t FOLDER_NAMES < <(jq -r '.folders[].name' "$CONFIG_FILE" 2>/dev/null)
      readarray -t FOLDER_TITLES < <(jq -r '.folders[].title' "$CONFIG_FILE" 2>/dev/null)

      FOLDERS=()

      # Build folder dictionary
      for i in "${!FOLDER_NAMES[@]}"; do
        FOLDERS+=("${FOLDER_NAMES[$i]}|${FOLDER_TITLES[$i]}")
        log "Added folder: ${FOLDER_NAMES[$i]} (${FOLDER_TITLES[$i]})" "debug"
      done

      log "Loaded ${#FOLDERS[@]} folders from configuration" "info"

      local missing_fields=()

      if [ -z "$SITE_NAME" ] || [ "$SITE_NAME" = "null" ]; then
        missing_fields+=("site_name")
      fi

      if [ -z "$CHECKMK_VERSION" ] || [ "$CHECKMK_VERSION" = "null" ]; then
        missing_fields+=("checkmk_version")
      fi

      if [ -z "$EXPECTED_HASH" ] || [ "$EXPECTED_HASH" = "null" ]; then
        missing_fields+=("expected_hash")
      fi

      if [ ${#FOLDERS[@]} -eq 0 ]; then
        missing_fields+=("folders")
      fi

      if [ ${#missing_fields[@]} -gt 0 ]; then
        log "Missing required configuration fields in $CONFIG_FILE:" "error"
        for field in "${missing_fields[@]}"; do
          echo " - $field"
        done
        exit 1
      fi
    else
      log "jq is required but not installed" "error"
      log "Install jq with: apt-get install -y jq" "info"
      exit 1
    fi
  else
    log "No configuration file found" "error"
    exit 1
  fi

  # Set derived variables based on loaded configuration
  PACKAGE_FILE="check-mk-raw-${CHECKMK_VERSION}_0.jammy_amd64.deb"
  DOWNLOAD_URL="https://download.checkmk.com/checkmk/${CHECKMK_VERSION}/${PACKAGE_FILE}"

  # Build base API URL
  API_BASE_URL="http://${API_HOST}:${API_PORT}"
  log "API base URL: $API_BASE_URL" "debug"
}
