#!/bin/bash

# =============================================================================
# CheckMk Configuration Module
# Core settings used throughout the installation process
# =============================================================================

# API connection settings
API_MAX_ATTEMPTS=5
API_RETRY_DELAY=5
API_USERNAME="cmkadmin"

# Installation paths
PACKAGE_PREFIX="check-mk-raw"
AGENT_PACKAGE_PREFIX="check-mk-agent"
UBUNTU_CODENAME="jammy" # Ubuntu 22.04

# Default file paths
DEFAULT_CONFIG_FILE="config.json"
DEFAULT_LOG_FILE="checkmk_setup.log"

# Alternative agent paths to try
AGENT_PATH_TEMPLATES=(
  "http://localhost/%s/check_mk/agents/"
  "http://localhost/%s/agents/"
  "http://localhost/%s/check_mk/check_mk/agents/"
)

# Download URL template
DOWNLOAD_URL_TEMPLATE="https://download.checkmk.com/checkmk/%s/%s"

# Runtime settings
DEBUG_MODE=${DEBUG_MODE:-false}
