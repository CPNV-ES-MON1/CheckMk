#!/bin/bash

# =============================================================================
# Title:        CheckMk Common Utilities Module
# Description:  Common functions for logging, task execution, and utilities
#               used across the CheckMk installation process
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2023-05-08
# Last Update:  2023-05-28
# Version:      1.0.1
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Log messages with status and proper formatting - Updated for better log format
log() {
  local message=$1
  local level=$2 # "success", "error", "warning", "info", "debug"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  # Skip debug messages unless debug mode is enabled
  if [ "$level" = "debug" ] && [ "$DEBUG_MODE" = false ]; then
    return
  fi

  # Set level text with consistent uppercase format
  local level_text
  case "$level" in
  "success")
    level_text="SUCCESS"
    echo -e "[$timestamp] [\033[32m$level_text\033[0m] $message"
    ;;
  "error")
    level_text="ERROR"
    echo -e "[$timestamp] [\033[31m$level_text\033[0m] $message"
    ;;
  "warning")
    level_text="WARNING"
    echo -e "[$timestamp] [\033[33m$level_text\033[0m] $message"
    ;;
  "info")
    level_text="INFO"
    echo -e "[$timestamp] [\033[34m$level_text\033[0m] $message"
    ;;
  "debug")
    level_text="DEBUG"
    echo -e "[$timestamp] [\033[35m$level_text\033[0m] $message"
    ;;
  *)
    level_text="MESSAGE"
    echo -e "[$timestamp] [$level_text] $message"
    ;;
  esac

  # Log to file if log file is defined - ALWAYS APPEND, never overwrite
  if [ -n "$LOG_FILE" ]; then
    # For log files, don't use colors and always append
    echo "[$timestamp] [$level_text] $message" >>"$LOG_FILE"
  fi
}

# Progress spinner for long-running operations
show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  local temp_message=$2

  tput civis # Hide cursor

  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "[$timestamp] [\033[34mINFO\033[0m] %s [%c] " "$temp_message" "${spinstr}"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\r"
  done

  printf "\r                                                    \r"
  tput cnorm # Show cursor
}

# Enhanced execute_task with progress indicator for long operations
execute_task_with_spinner() {
  local message=$1
  local command=$2
  local temp_output=$(mktemp)
  local start_time=$(date +%s)

  if [ "$DEBUG_MODE" = true ]; then
    log "Executing command: $command" "debug"
  fi

  log "$message..." "info"

  # Run the command in background
  $command >"$temp_output" 2>&1 &
  local command_pid=$!

  # Show spinner while command is running
  show_spinner $command_pid "$message"

  # Wait for command to finish
  wait $command_pid
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  if [ $exit_code -eq 0 ]; then
    log "$message (completed in ${duration}s)" "success"

    if [ "$DEBUG_MODE" = true ]; then
      if [ -s "$temp_output" ]; then
        log "Command output:" "debug"
        cat "$temp_output" | while read -r line; do
          log "  $line" "debug"
        done
      else
        log "Command produced no output" "debug"
      fi
    fi
  else
    log "$message failed (exit code: $exit_code, duration: ${duration}s)" "error"
    log "Command that failed: $command" "error"
    log "Error output:" "error"

    # Always show error output regardless of debug mode
    cat "$temp_output" | while read -r line; do
      log "  $line" "error"
    done

    if [ "$DEBUG_MODE" = true ]; then
      # Get stack trace
      local stack_size=${#FUNCNAME[@]}
      log "Stack trace:" "debug"
      for ((i = 1; i < $stack_size; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i - 1))]}"
        local src="${BASH_SOURCE[$i]}"
        log "  at $func() in $src:$line" "debug"
      done

      # Add system state information
      log "System state at time of error:" "debug"
      log "  Disk space: $(df -h / | awk 'NR==2 {print $4}') available" "debug"
      log "  Memory: $(free -h | grep Mem | awk '{print $4}') free" "debug"
      log "  Load average: $(cat /proc/loadavg)" "debug"
    fi

    rm -f "$temp_output"
    exit 1
  fi

  rm -f "$temp_output"
  return 0
}

# Enhanced execute_task with more detailed logging
execute_task() {
  local message=$1
  local command=$2
  local long_operation=$3
  local temp_output=$(mktemp)
  local start_time=$(date +%s)

  if [ "$DEBUG_MODE" = true ]; then
    # Sanitize the command before logging it
    local sanitized_command=$(sanitize_for_log "$command")
    log "Executing command: $sanitized_command" "debug"
  fi

  if [ "$long_operation" = "true" ]; then
    log "$message (this might take several minutes)..." "info"
    log "Started at $(date +"%H:%M:%S")" "debug"
  else
    log "$message" "info"
  fi

  if eval "$command" >"$temp_output" 2>&1; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log "$message" "success"

    if [ "$DEBUG_MODE" = true ]; then
      log "Command completed in ${duration}s" "debug"
      if [ -s "$temp_output" ]; then
        log "Command output:" "debug"
        cat "$temp_output" | while read -r line; do
          log "  $line" "debug"
        done
      else
        log "Command produced no output" "debug"
      fi
    fi
  else
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log "$message failed (exit code: $exit_code, duration: ${duration}s)" "error"
    log "Command that failed: $command" "debug"
    log "Error output:" "error"
    cat "$temp_output" >&2

    if [ "$DEBUG_MODE" = true ]; then
      # Get stack trace
      local stack_size=${#FUNCNAME[@]}
      log "Stack trace:" "debug"
      for ((i = 1; i < $stack_size; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i - 1))]}"
        local src="${BASH_SOURCE[$i]}"
        log "  at $func() in $src:$line" "debug"
      done
    fi

    rm -f "$temp_output"
    exit 1
  fi
  rm -f "$temp_output"
}

# Execute with spinner for long running tasks - completely fixed version to eliminate all duplicate messages
execute_with_spinner() {
  local message=$1
  local command=$2
  local timeout=${3:-1800} # Default timeout of 30 minutes
  local temp_output=$(mktemp)
  local start_time=$(date +%s)
  local command_pid="" # Initialize command_pid variable
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  # Don't log the message initially - we'll show it with the spinner

  # Run the command in background first, so command_pid is defined
  eval "$command" >"$temp_output" 2>&1 &
  command_pid=$!

  # Now create the watchdog process with access to the correct command_pid
  (
    sleep $timeout
    # Check if the process is still running after timeout
    if ps -p $command_pid >/dev/null 2>&1; then
      log "Command timed out after ${timeout}s: $command" "error"
      kill -9 $command_pid 2>/dev/null
    fi
  ) &
  local watchdog_pid=$!

  # Show spinner while command is running
  local sp='/-\|'
  local i=0

  # To prevent duplicate output, we'll store the last elapsed time we reported
  local last_reported=0

  while ps -p $command_pid >/dev/null 2>&1; do
    local elapsed=$(($(date +%s) - start_time))
    timestamp=$(date +"%Y-%m-%d %H:%M:%S") # Update timestamp for real-time display

    # Only update the spinner, never output new lines while the command is running
    printf "\r[$timestamp] [\033[34mINFO\033[0m] %s %c (%ds)" "$message" "${sp:i++%4:1}" "$elapsed"
    sleep 0.5
  done

  # Kill the watchdog as it's no longer needed
  kill $watchdog_pid 2>/dev/null || true # Ignore errors if watchdog already terminated

  # Clear the spinner line completely
  printf "\r                                                                              \r"

  # Check command result
  wait $command_pid || true # Don't exit on error from wait
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  if [ $exit_code -eq 0 ]; then
    log "$message (completed in ${duration}s)" "success"

    if [ "$DEBUG_MODE" = true ] && [ -s "$temp_output" ]; then
      log "Command output:" "debug"
      cat "$temp_output" | while read -r line; do
        log "  $line" "debug"
      done
    fi
  else
    log "$message failed (exit code: $exit_code, duration: ${duration}s)" "error"
    log "Command that failed: $command" "error"
    log "Error output:" "error"
    cat "$temp_output" | while read -r line; do
      log "  $line" "error"
    done

    rm -f "$temp_output"
    return $exit_code
  fi

  rm -f "$temp_output"
  return 0
}

# Enhanced command_exists with debug output
command_exists() {
  local cmd=$1
  if command -v "$cmd" >/dev/null 2>&1; then
    log "Command '$cmd' found: $(command -v "$cmd")" "debug"
    return 0
  else
    log "Command '$cmd' not found in PATH" "debug"
    return 1
  fi
}

# Enhanced display_summary with simplified output
display_summary() {
  SERVER_IP=$(hostname -I | awk '{print $1}')
  local installation_end_time=$(date +"%Y-%m-%d %H:%M:%S")

  log "═════════════════════════════════════════" "info"
  log "         Installation Summary            " "info"
  log "═════════════════════════════════════════" "info"

  if [ "$DO_INSTALL" = true ]; then
    log "CheckMk $INSTALLED_VERSION has been successfully installed" "info"
    log "Access the web interface: http://$SERVER_IP/$SITE_NAME/" "info"
    log "Credentials:" "info"
    log "  • Username: cmkadmin" "info"
    log "  • Password: $SITE_PASSWORD" "info"
    log "For CLI administration: omd su $SITE_NAME" "info"
  fi

  if [ "$DO_INSTALL_AGENT" = true ]; then
    log "CheckMk agent has been installed and configured" "info"
    log "Agent status: $(systemctl is-active check_mk_agent.socket)" "info"
  fi

  if [ "$DO_ADD_HOSTS" = true ]; then
    log "Hosts have been configured from config.json" "info"
    if [ "$DEBUG_MODE" = true ]; then
      local host_count=$(jq '.hosts | length' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
      log "Number of configured hosts: $host_count" "info"
    fi
  fi

  log "═════════════════════════════════════════" "info"
}

# Display agent-specific summary
display_agent_summary() {
  log "═════════════════════════════════════════" "info"
  log "         Agent Installation Summary      " "info"
  log "═════════════════════════════════════════" "info"

  log "CheckMk agent has been installed and configured" "info"
  log "Agent status: $(systemctl is-active check_mk_agent.socket)" "info"
  log "Agent version: $(dpkg-query -W -f='${Version}' check-mk-agent 2>/dev/null || echo "unknown")" "info"
  log "For site: $SITE_NAME" "info"

  log "═════════════════════════════════════════" "info"
}

# Progress bar function for use with wget/curl
show_progress_bar() {
  local current=$1
  local total=$2
  local percent=$((current * 100 / total))
  local progress=$((current * 50 / total))

  printf "\r["
  for ((i = 0; i < progress; i++)); do printf "#"; done
  for ((i = progress; i < 50; i++)); do printf " "; done
  printf "] %3d%% (%d/%d)" $percent $current $total

  if [ "$current" -eq "$total" ]; then
    printf "\n"
  fi
}

# Enhanced function to sanitize sensitive data for logs
sanitize_for_log() {
  local input=$1

  # Replace passwords and tokens with masked versions
  local sanitized=$input

  # Replace password in JSON
  sanitized=$(echo "$sanitized" | sed -E 's/"password":"[^"]+"/\"password\":\"*****\"/g')

  # Replace tokens and keys
  sanitized=$(echo "$sanitized" | sed -E 's/"token":"[^"]+"/\"token\":\"*****\"/g')
  sanitized=$(echo "$sanitized" | sed -E 's/"api_key":"[^"]+"/\"api_key\":\"*****\"/g')

  # Replace Basic Auth headers
  sanitized=$(echo "$sanitized" | sed -E 's/(Authorization: Basic )[^ ]+/\1*****/g')

  echo "$sanitized"
}
