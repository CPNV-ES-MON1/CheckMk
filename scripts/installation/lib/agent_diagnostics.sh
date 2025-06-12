#!/bin/bash

# =============================================================================
# CheckMk Agent Diagnostics Module
# Functions for troubleshooting agent installation and connection issues
# =============================================================================

diagnose_agent() {
  local site_name=$1

  log "Running agent diagnostics for site: $site_name" "info"
  log "------------------------------------------------" "info"

  local site_running=false
  if omd status "$site_name" | grep -q "Overall state:.*running"; then
    log "Site is running correctly" "success"
    site_running=true
  else
    log "Site is not running properly" "error"
    log "Try starting it with: omd start $site_name" "info"
    return 1
  fi

  local agent_found=false
  local agent_url=""

  # Display spinner animation during search
  local sp='/-\|'
  local i=0
  printf "[$timestamp] [\033[34mINFO\033[0m] Searching for agent packages "

  # Search for packages in common CheckMk paths
  for path in "check_mk/agents/" "agents/" "check_mk/check_mk/agents/"; do
    curl -s "http://localhost/$site_name/$path" | grep -o 'href="[^"]*\.deb"' | sed 's/href="//g;s/"//g' | while read -r agent; do
      printf "\r[$timestamp] [\033[34mINFO\033[0m] Searching for agent packages %c" "${sp:i++%4:1}"
      if [[ "$agent" == *.deb ]]; then
        agent_found=true
        agent_url="http://localhost/$site_name/$path$agent"
        printf "\r                                                   \r"
        log "Found agent package: $agent" "success"
        log "URL: $agent_url" "info"
      fi
    done

    if [ "$agent_found" = true ]; then
      break
    fi
  done

  printf "\r                                                   \r"

  if [ "$agent_found" = false ]; then
    log "No agent packages found" "warning"
    log "Check the web interface for available packages" "info"
  fi

  log "Checking agent socket status..." "info"
  if systemctl is-active check_mk_agent.socket &>/dev/null; then
    log "Agent socket is active" "success"
  else
    log "Agent socket is not active" "warning"
    log "Try starting it with: systemctl start check_mk_agent.socket" "info"
  fi

  log "Checking agent port (6556)..." "info"
  if ss -tuln | grep -q ":6556"; then
    log "Agent port 6556 is open" "success"
  else
    log "Agent port 6556 is not open" "warning"
    log "Check if the agent is running" "info"
  fi

  log "Testing agent connection..." "info"
  if command_exists telnet; then
    if timeout 2 bash -c "echo '' > /dev/tcp/localhost/6556" 2>/dev/null; then
      log "Connection to agent successful" "success"
    else
      log "Cannot connect to agent on port 6556" "warning"
    fi
  else
    log "Telnet not available for connection test" "warning"
  fi

  log "Checking for installed agent package..." "info"
  if dpkg -l | grep -q check-mk-agent; then
    local agent_version=$(dpkg -l | grep check-mk-agent | awk '{print $3}')
    log "Agent package installed (version: $agent_version)" "success"
  else
    log "No CheckMk agent package found" "warning"
    log "You need to install the agent package" "info"
  fi

  log "------------------------------------------------" "info"
  log "Diagnostic Summary:" "info"
  log "1. Make sure the CheckMk site is running: omd start $site_name" "info"
  log "2. Download the agent from: http://localhost/$site_name/" "info"
  log "3. Install it with: sudo apt install -y ./DOWNLOADED_PACKAGE.deb" "info"
  log "4. Enable and start: sudo systemctl enable --now check_mk_agent.socket" "info"
  log "------------------------------------------------" "info"
}

verify_agent_installation() {
  local site_name=$1

  log "Verifying agent installation for site: $site_name" "info"

  if ! dpkg -l | grep -q check-mk-agent; then
    log "Agent package is not installed" "error"
    return 1
  fi

  if ! systemctl is-active check_mk_agent.socket &>/dev/null; then
    log "Agent service is not running" "error"
    log "Attempting to start agent service..." "info"

    if systemctl start check_mk_agent.socket; then
      log "Successfully started agent service" "success"
    else
      log "Failed to start agent service" "error"
      return 1
    fi
  fi

  if ! ss -tuln | grep -q ":6556"; then
    log "Agent port is not open" "error"
    return 1
  fi

  log "Agent is properly installed and running" "success"
  return 0
}

fix_agent_issues() {
  local site_name=$1

  log "Attempting to fix agent issues..." "info"

  log "Restarting agent service..." "info"
  systemctl restart check_mk_agent.socket

  if systemctl is-active check_mk_agent.socket &>/dev/null; then
    log "Agent service is now running" "success"
  else
    log "Failed to restart agent service" "error"
    log "Trying to reinstall the agent..." "info"

    local agent_url=""
    for path in "check_mk/agents/" "agents/" "check_mk/check_mk/agents/"; do
      curl -s "http://localhost/$site_name/$path" | grep -o 'href="[^"]*\.deb"' | sed 's/href="//g;s/"//g' | while read -r agent; do
        if [[ "$agent" == *.deb ]]; then
          agent_url="http://localhost/$site_name/$path$agent"
          log "Found agent package: $agent" "success"
          break
        fi
      done

      if [ -n "$agent_url" ]; then
        break
      fi
    done

    if [ -n "$agent_url" ]; then
      log "Downloading agent from: $agent_url" "info"
      wget -q "$agent_url" -O "agent.deb"

      log "Reinstalling agent package..." "info"
      DEBIAN_FRONTEND=noninteractive apt install -y -q ./agent.deb

      log "Enabling and starting agent service..." "info"
      systemctl enable --now check_mk_agent.socket

      if systemctl is-active check_mk_agent.socket &>/dev/null; then
        log "Agent service is now running" "success"
        return 0
      else
        log "Failed to fix agent issues" "error"
        return 1
      fi
    else
      log "Could not find agent package" "error"
      return 1
    fi
  fi

  return 0
}

diagnose_api_issues() {
  local site_name=$1

  log "Running API diagnostics for site: $site_name" "info"
  log "------------------------------------------------" "info"

  if ! omd status "$site_name" | grep -q "Overall state:.*running"; then
    log "Site is not running properly - this will affect API operations" "error"
    log "Try starting it with: omd start $site_name" "info"
    return 1
  fi

  log "Checking Apache status..." "info"
  if ! systemctl is-active apache2 &>/dev/null; then
    log "Apache is not running - required for API access" "error"
    log "Try starting it with: systemctl start apache2" "info"
  else
    log "Apache is running" "success"
  fi

  log "Checking API connectivity..." "info"
  if [ -z "$SITE_PASSWORD" ]; then
    log "Site password not available - cannot check API connectivity" "error"
    return 1
  fi

  local status_code=$(curl --silent --output /dev/null \
    --write-out "%{http_code}" \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Accept: application/json" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/version")

  log "API status code: $status_code" "info"

  case "$status_code" in
  200 | 201 | 202)
    log "API is reachable and returning success" "success"
    ;;
  401)
    log "API authentication failed - check credentials" "error"
    ;;
  403)
    log "API forbidden - user may not have correct permissions" "error"
    ;;
  404)
    log "API endpoint not found - check URL and site name" "error"
    ;;
  0)
    log "Could not connect to API - check network connectivity" "error"
    ;;
  *)
    log "API returned unexpected status code: $status_code" "warning"
    ;;
  esac

  log "Testing folder creation via API..." "info"
  local test_folder_name="api_test_$(date +%s)"

  local folder_response=$(curl --silent \
    --request POST \
    --header "Authorization: Basic $(echo -n "${API_USERNAME}:${SITE_PASSWORD}" | base64)" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --data "{\"name\":\"$test_folder_name\",\"title\":\"API Test Folder\",\"parent\":\"/\"}" \
    --write-out "\n%{http_code}" \
    "${API_BASE_URL}/${site_name}/check_mk/api/1.0/domain-types/folder_config/collections/all")

  local folder_status_code=$(echo "$folder_response" | tail -n1)

  if [[ "$folder_status_code" -ge 200 && "$folder_status_code" -lt 300 ]]; then
    log "API folder creation test succeeded" "success"
  else
    log "API folder creation test failed with status: $folder_status_code" "error"
    log "This indicates problems with host creation may be related to API permissions" "info"
  fi

  log "------------------------------------------------" "info"
  log "API Diagnostic Summary:" "info"
  log "1. Ensure the site is running: omd status $site_name" "info"
  log "2. Verify Apache is running: systemctl status apache2" "info"
  log "3. Check API credentials are correct" "info"
  log "4. Ensure the site user has proper permissions" "info"
  log "------------------------------------------------" "info"

  return 0
}
