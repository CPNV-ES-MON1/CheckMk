#!/bin/bash

# =============================================================================
# CheckMk Log Rotation Module
# Functions for managing log files to prevent disk space issues
# =============================================================================

setup_log_directory() {
  local log_dir=$1

  if [ ! -d "$log_dir" ]; then
    mkdir -p "$log_dir"
    chmod 755 "$log_dir"
    log "Created log directory: $log_dir" "info"
  fi

  if [ ! -w "$log_dir" ]; then
    log "Warning: Log directory $log_dir is not writable" "warning"
    log "Falling back to current directory for logs" "warning"
    return 1
  fi

  return 0
}

rotate_logs() {
  local log_dir=$1
  local max_logs=${2:-30}

  if [ ! -d "$log_dir" ]; then
    log "Cannot rotate logs: Directory $log_dir does not exist" "warning"
    return 1
  fi

  local log_count=$(find "$log_dir" -name "checkmk_setup_*.log" | wc -l)

  if [ "$log_count" -gt "$max_logs" ]; then
    local files_to_remove=$((log_count - max_logs))
    log "Rotating logs: Removing $files_to_remove old log files" "info"

    # Remove oldest logs based on timestamp
    find "$log_dir" -name "checkmk_setup_*.log" -type f -printf "%T@ %p\n" |
      sort -n | head -n "$files_to_remove" | cut -d' ' -f2- |
      xargs rm -f

    log "Log rotation complete" "debug"
  else
    log "Log rotation not needed ($log_count logs, maximum is $max_logs)" "debug"
  fi

  return 0
}

create_log_summary() {
  local log_dir=$1
  local summary_file="$log_dir/summary.log"

  echo "CheckMk Installation Script Log Summary" >"$summary_file"
  echo "Generated: $(date)" >>"$summary_file"
  echo "----------------------------------------" >>"$summary_file"

  # Process all logs newest to oldest
  find "$log_dir" -name "checkmk_setup_*.log" -type f | sort -r |
    while read -r logfile; do
      local timestamp=$(basename "$logfile" | sed -E 's/checkmk_setup_([0-9_]+)\.log/\1/')
      local formatted_date=$(echo "$timestamp" | sed -E 's/([0-9]{8})_([0-9]{2})([0-9]{2})([0-9]{2})/\1 \2:\3:\4/')

      echo "" >>"$summary_file"
      echo "Log: $(basename "$logfile")" >>"$summary_file"
      echo "Date: $formatted_date" >>"$summary_file"

      # Extract only errors and success messages
      grep -E "\[(ERROR|SUCCESS)\]" "$logfile" >>"$summary_file"

      echo "----------------------------------------" >>"$summary_file"
    done

  # Silent completion (no log message)
  return 0
}
