#!/bin/bash

# =============================================================================
# CheckMk System Information Module
# Functions for collecting system information for diagnostics
# =============================================================================

collect_system_info() {
  local dir_name=$1
  log "Collecting system information in $dir_name..." "info"

  mkdir -p "$dir_name" && cd "$dir_name"

  # Each command has a specified timeout limit to prevent hanging
  execute_with_spinner "Collecting installed packages" "dpkg --get-selections > packages.txt" 60
  execute_with_spinner "Collecting open ports" "ss -tuln > ports.txt" 15
  execute_with_spinner "Collecting running services" "systemctl list-units --type=service --state=running > services.txt" 15
  execute_with_spinner "Collecting service statuses" "service --status-all > services-status.txt" 15
  execute_with_spinner "Collecting hardware information" "lshw -short > hardware.txt" 30
  execute_with_spinner "Collecting disk information" "lsblk > disks.txt" 5
  execute_with_spinner "Backing up sources list" "cp /etc/apt/sources.list sources.list" 2
  execute_with_spinner "Collecting network configuration" "ip addr > network.txt" 5
  execute_with_spinner "Collecting DNS information" "cat /etc/resolv.conf > dns.txt" 2
  execute_with_spinner "Collecting process information" "ps aux > processes.txt" 10

  cd "$BASE_DIR"
  log "System information collection complete" "success"
}
