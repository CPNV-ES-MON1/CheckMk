#!/bin/bash

# =============================================================================
# Title:        CheckMk Agent Diagnostics Module
# Description:  Functions for diagnosing and troubleshooting CheckMk agent
#               installation and connection issues
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-06-10
# Last Update:  2023-06-10
# Version:      1.0.0
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Diagnose agent issues and provide solutions
diagnose_agent() {
  local site_name=$1

  log "Running agent diagnostics for site: $site_name" "info"
  log "------------------------------------------------" "info"

  # Check site status
  log "Checking site status..." "info"
  local site_running=false
  if omd status "$site_name" | grep -q "Overall state:.*running"; then
    log "Site is running correctly" "success"
    site_running=true
  else
    log "Site is not running properly" "error"
    log "Try starting it with: omd start $site_name" "info"
    return 1
  fi

  # Check available agent packages
  log "Checking available agent packages..." "info"
  local agent_found=false
  local agent_url=""

  # Show spinner while checking
  local sp='/-\|'
  local i=0
  printf "[$timestamp] [\033[34mINFO\033[0m] Searching for agent packages "

  # Try different paths to find agent packages
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

  # Check agent socket status
  log "Checking agent socket status..." "info"
  if systemctl is-active check_mk_agent.socket &>/dev/null; then
    log "Agent socket is active" "success"
  else
    log "Agent socket is not active" "warning"
    log "Try starting it with: systemctl start check_mk_agent.socket" "info"
  fi

  # Check agent TCP port
  log "Checking agent port (6556)..." "info"
  if ss -tuln | grep -q ":6556"; then
    log "Agent port 6556 is open" "success"
  else
    log "Agent port 6556 is not open" "warning"
    log "Check if the agent is running" "info"
  fi

  # Test agent connection
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

  # Check for installed agent package
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

# Verify agent installation and connectivity
verify_agent_installation() {
  local site_name=$1

  log "Verifying agent installation for site: $site_name" "info"

  # Check if agent package is installed
  if ! dpkg -l | grep -q check-mk-agent; then
    log "Agent package is not installed" "error"
    return 1
  fi

  # Check if agent service is running
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

  # Check if agent port is listening
  if ! ss -tuln | grep -q ":6556"; then
    log "Agent port is not open" "error"
    return 1
  fi

  log "Agent is properly installed and running" "success"
  return 0
}

# Fix common agent issues
fix_agent_issues() {
  local site_name=$1

  log "Attempting to fix agent issues..." "info"

  # Restart agent service
  log "Restarting agent service..." "info"
  systemctl restart check_mk_agent.socket

  # Check if this fixed the issue
  if systemctl is-active check_mk_agent.socket &>/dev/null; then
    log "Agent service is now running" "success"
  else
    log "Failed to restart agent service" "error"
    log "Trying to reinstall the agent..." "info"

    # Try to find agent package
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
