#!/bin/bash

# =============================================================================
# Title:        CheckMk Configuration Module
# Description:  Central location for all configuration settings
#               used across the CheckMk installation process
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-06-10
# Last Update:  2023-06-10
# Version:      1.0.0
#
# Usage:        Sourced by setup.sh and other modules
# =============================================================================

# API connection settings
API_MAX_ATTEMPTS=5      # Maximum number of API connection attempts
API_RETRY_DELAY=5       # Delay in seconds between API connection attempts
API_USERNAME="cmkadmin" # Default CheckMk admin username

# Installation paths
PACKAGE_PREFIX="check-mk-raw"
AGENT_PACKAGE_PREFIX="check-mk-agent"
UBUNTU_CODENAME="jammy" # Ubuntu codename (jammy = 22.04)

# Default file paths (can be overridden by setup.sh)
DEFAULT_CONFIG_FILE="config.json"
DEFAULT_LOG_FILE="checkmk_setup.log"

# Alternative agent paths to try
AGENT_PATH_TEMPLATES=(
  "http://localhost/%s/check_mk/agents/"
  "http://localhost/%s/agents/"
  "http://localhost/%s/check_mk/check_mk/agents/"
)

# Default CheckMk download URL template
DOWNLOAD_URL_TEMPLATE="https://download.checkmk.com/checkmk/%s/%s"

# Execution flags
DEBUG_MODE=${DEBUG_MODE:-false}
