#!/bin/bash

# =============================================================================
# CheckMk Common Utilities Module
# Functions for logging, task execution, and utility operations
# =============================================================================

log() {
  local message=$1
  local level=$2
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  if [ "$level" != "debug" ] || [ "$DEBUG_MODE" = true ]; then
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
  fi

  if [ -n "$LOG_FILE" ]; then
    local level_text
    case "$level" in
    "success") level_text="SUCCESS" ;;
    "error") level_text="ERROR" ;;
    "warning") level_text="WARNING" ;;
    "info") level_text="INFO" ;;
    "debug") level_text="DEBUG" ;;
    *) level_text="MESSAGE" ;;
    esac

    echo "[$timestamp] [$level_text] $message" >>"$LOG_FILE"
  fi
}

show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  local temp_message=$2

  tput civis

  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "[$timestamp] [\033[34mINFO\033[0m] %s [%c] " "$temp_message" "${spinstr}"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\r"
  done

  printf "\r                                                    \r"
  tput cnorm
}

execute_task_with_spinner() {
  local message=$1
  local command=$2
  local temp_output=$(mktemp)
  local start_time=$(date +%s)

  if [ "$DEBUG_MODE" = true ]; then
    log "Executing command: $command" "debug"
  fi

  log "$message..." "info"

  $command >"$temp_output" 2>&1 &
  local command_pid=$!

  show_spinner $command_pid "$message"

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

    cat "$temp_output" | while read -r line; do
      log "  $line" "error"
    done

    if [ "$DEBUG_MODE" = true ]; then
      local stack_size=${#FUNCNAME[@]}
      log "Stack trace:" "debug"
      for ((i = 1; i < $stack_size; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i - 1))]}"
        local src="${BASH_SOURCE[$i]}"
        log "  at $func() in $src:$line" "debug"
      done

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

execute_task() {
  local message=$1
  local command=$2
  local long_operation=$3
  local temp_output=$(mktemp)
  local start_time=$(date +%s)

  if [ "$DEBUG_MODE" = true ]; then
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

execute_with_spinner() {
  local message=$1
  local command=$2
  local timeout=${3:-1800}
  local temp_output=$(mktemp)
  local start_time=$(date +%s)
  local command_pid=""
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  eval "$command" >"$temp_output" 2>&1 &
  command_pid=$!

  (
    sleep $timeout
    if ps -p $command_pid >/dev/null 2>&1; then
      log "Command timed out after ${timeout}s: $command" "error"
      kill -9 $command_pid 2>/dev/null
    fi
  ) &
  local watchdog_pid=$!

  local sp='/-\|'
  local i=0
  local last_reported=0

  while ps -p $command_pid >/dev/null 2>&1; do
    local elapsed=$(($(date +%s) - start_time))
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    printf "\r[$timestamp] [\033[34mINFO\033[0m] %s %c (%ds)" "$message" "${sp:i++%4:1}" "$elapsed"
    sleep 0.5
  done

  kill $watchdog_pid 2>/dev/null || true

  printf "\r                                                                              \r"

  wait $command_pid || true
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

display_summary() {
  SERVER_IP=$(hostname -I | awk '{print $1}')
  local installation_end_time=$(date +"%Y-%m-%d %H:%M:%S")

  log "================================================================" "info"
  log "                    Installation Summary                        " "info"
  log "================================================================" "info"

  if [ "$DO_INSTALL" = true ]; then
    log "CheckMk $INSTALLED_VERSION has been successfully installed" "info"
    log "Access the web interface: http://$SERVER_IP/$SITE_NAME/" "info"
    log "Credentials: (password shown only once, not saved anywhere)" "info"
    log "  • Username: cmkadmin" "info"
    log "  • Password: $SITE_PASSWORD" "info"
    log "For CLI administration: omd su $SITE_NAME" "info"
  fi

  if [ "$DO_INSTALL_AGENT" = true ]; then
    log "CheckMk agent has been installed and configured" "info"

    local agent_version=$(dpkg-query -W -f='${Version}' check-mk-agent 2>/dev/null || echo "unknown")
    log "Agent version: $agent_version" "info"

    local agent_status=$(get_agent_status)

    if [ "$agent_status" = "operational" ]; then
      log "Agent status: OPERATIONAL" "info"
    elif [ "$agent_status" = "active" ]; then
      log "Agent status: ACTIVE" "info"
    elif [ "$agent_status" = "wsl-pending" ]; then
      log "Agent status: INSTALLED (needs configuration in WSL)" "info"
      log "Run: sudo cmk-agent-ctl enable" "info"
    else
      log "Agent status: $agent_status" "info"
      log "Check detailed status with: sudo cmk-agent-ctl status" "info"
    fi
  fi

  if [ "$DO_ADD_HOSTS" = true ]; then
    log "Hosts have been configured from config.json" "info"
    if [ "$DEBUG_MODE" = true ]; then
      local host_count=$(jq '.hosts | length' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
      log "Number of configured hosts: $host_count" "info"
    fi
  fi

  log "================================================================" "info"
}

display_agent_summary() {
  log "================================================================" "info"
  log "                Agent Installation Summary                     " "info"
  log "================================================================" "info"

  log "CheckMk agent has been installed and configured" "info"

  local agent_version=$(dpkg-query -W -f='${Version}' check-mk-agent 2>/dev/null || echo "unknown")
  log "Agent version: $agent_version" "info"

  local agent_status=$(get_agent_status)

  if [ "$agent_status" = "operational" ]; then
    log "Agent status: OPERATIONAL" "info"
  elif [ "$agent_status" = "active" ]; then
    log "Agent status: ACTIVE" "info"
  elif [ "$agent_status" = "wsl-pending" ]; then
    log "Agent status: INSTALLED (needs configuration in WSL)" "info"
    log "Run the following command to enable the agent:" "info"
    log "  sudo cmk-agent-ctl enable" "info"
  else
    log "Agent status: $agent_status" "info"
    log "For detailed status, run: sudo cmk-agent-ctl status" "info"
  fi

  log "For site: $SITE_NAME" "info"

  log "================================================================" "info"
}

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

sanitize_password() {
  local input=$1
  local length=${#input}

  if [ $length -eq 0 ]; then
    echo ""
    return
  fi

  local first_char="${input:0:1}"
  local mask=$(printf '%*s' $((length - 1)) | tr ' ' '*')
  echo "${first_char}${mask}"
}

sanitize_for_log() {
  local input=$1
  local sanitized=$input

  sanitized=$(echo "$sanitized" | sed -E 's/(password=")[^"]+(")/\1*****\2/g')
  sanitized=$(echo "$sanitized" | sed -E 's/(password: ")[^"]+(")/\1*****\2/g')
  sanitized=$(echo "$sanitized" | sed -E 's/"password":"[^"]+"/\"password\":\"*****\"/g')
  sanitized=$(echo "$sanitized" | sed -E 's/"token":"[^"]+"/\"token\":\"*****\"/g')
  sanitized=$(echo "$sanitized" | sed -E 's/"api_key":"[^"]+"/\"api_key\":\"*****\"/g')
  sanitized=$(echo "$sanitized" | sed -E 's/(Authorization: Basic )[^ ]+/\1*****/g')

  echo "$sanitized"
}
