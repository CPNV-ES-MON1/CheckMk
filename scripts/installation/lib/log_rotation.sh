#!/bin/bash

# =============================================================================
# Title:        CheckMk Log Rotation Module
# Description:  Functions for managing and rotating log files
#               to prevent disk space issues over time
# Author:       Rui Monteiro (rui.monteiro@eduvaud.ch)
# Created:      2025-06-11
# Last Update:  2025-06-11
# Version:      1.0.0
#
# Usage:        Sourced by setup.sh
# =============================================================================

# Setup log directory with proper permissions
setup_log_directory() {
  local log_dir=$1

  # Create log directory if it doesn't exist
  if [ ! -d "$log_dir" ]; then
    mkdir -p "$log_dir"
    # Set appropriate permissions
    chmod 755 "$log_dir"
    log "Created log directory: $log_dir" "info"
  fi

  # Check if directory is writable
  if [ ! -w "$log_dir" ]; then
    log "Warning: Log directory $log_dir is not writable" "warning"
    log "Falling back to current directory for logs" "warning"
    return 1
  fi

  return 0
}

# Rotate old log files to prevent disk space issues
rotate_logs() {
  local log_dir=$1
  local max_logs=${2:-30} # Default to keeping 30 logs

  # Check if log directory exists
  if [ ! -d "$log_dir" ]; then
    log "Cannot rotate logs: Directory $log_dir does not exist" "warning"
    return 1
  fi

  # Count number of log files
  local log_count=$(find "$log_dir" -name "checkmk_setup_*.log" | wc -l)

  # If we have more than max_logs, remove the oldest ones
  if [ "$log_count" -gt "$max_logs" ]; then
    local files_to_remove=$((log_count - max_logs))
    log "Rotating logs: Removing $files_to_remove old log files" "info"

    # Find oldest log files and remove them
    find "$log_dir" -name "checkmk_setup_*.log" -type f -printf "%T@ %p\n" |
      sort -n | head -n "$files_to_remove" | cut -d' ' -f2- |
      xargs rm -f

    log "Log rotation complete" "debug"
  else
    log "Log rotation not needed ($log_count logs, maximum is $max_logs)" "debug"
  fi

  return 0
}

# Create a log summary file with key information from all logs - modified to be silent
create_log_summary() {
  local log_dir=$1
  local summary_file="$log_dir/summary.log"

  # Create or overwrite summary file silently
  echo "CheckMk Installation Script Log Summary" >"$summary_file"
  echo "Generated: $(date)" >>"$summary_file"
  echo "----------------------------------------" >>"$summary_file"

  # Find all log files and extract key information
  find "$log_dir" -name "checkmk_setup_*.log" -type f | sort -r |
    while read -r logfile; do
      local timestamp=$(basename "$logfile" | sed -E 's/checkmk_setup_([0-9_]+)\.log/\1/')
      local formatted_date=$(echo "$timestamp" | sed -E 's/([0-9]{8})_([0-9]{2})([0-9]{2})([0-9]{2})/\1 \2:\3:\4/')

      echo "" >>"$summary_file"
      echo "Log: $(basename "$logfile")" >>"$summary_file"
      echo "Date: $formatted_date" >>"$summary_file"

      # Extract important information
      grep -E "\[(ERROR|SUCCESS)\]" "$logfile" >>"$summary_file"

      # Add separator
      echo "----------------------------------------" >>"$summary_file"
    done

  # Don't log completion message to avoid cluttering the output
  return 0
}
