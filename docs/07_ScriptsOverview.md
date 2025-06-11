# Scripts Overview

This document provides a comprehensive overview of all automation scripts included in the CheckMk monitoring solution.

## Repository Structure

```
scripts/
├── installation/           # Installation and configuration automation
│   ├── setup.sh           # Main installation script
│   ├── config.json        # Configuration template
│   └── lib/               # Library modules
│       ├── agent_diagnostics.sh   # Agent troubleshooting
│       ├── api_operations.sh      # CheckMk API interactions
│       ├── common.sh              # Shared utilities
│       ├── config_loader.sh       # Configuration management
│       ├── config.sh              # Default settings
│       ├── entity_management.sh   # Host/folder management
│       ├── installation.sh        # Package installation
│       ├── log_rotation.sh        # Log management
│       ├── site_management.sh     # Site operations
│       ├── system_checks.sh       # System validation
│       └── system_info.sh         # System information collection
└── notifications/         # Alert integration scripts
    ├── discord.py         # Discord webhook notifications
    └── glpi.py           # GLPI ticket management
```

## Installation Scripts

### Main Installation Script (setup.sh)

**Purpose**: Orchestrates the complete CheckMk server installation and configuration process.

**Key Features**:

- Automated CheckMk server installation and setup
- Site creation and configuration
- Host and folder configuration from JSON files
- MySQL plugin configuration for database monitoring
- Comprehensive error handling and logging
- System information collection for troubleshooting

**Usage**:

```bash
# Full server installation with host configuration
sudo ./setup.sh --install --add-hosts

# Server installation only
sudo ./setup.sh --install

# Add hosts to an existing site
sudo ./setup.sh --add-hosts

# Enable debug output
sudo ./setup.sh --debug --install
```

**Important**: This script is designed for CheckMk server installation and configuration. For agent installation on monitored hosts (Debian, Windows), follow the respective monitoring guides.

**Configuration**: Uses `config.json` for all settings including:

- CheckMk version and download settings
- Site configuration parameters
- Host and folder definitions
- API connection settings

### Library Modules

#### System Validation (system_checks.sh)

- Verifies root privileges and system requirements
- Installs necessary dependencies (jq, curl, wget, lshw)
- Checks existing installations to prevent conflicts
- Validates network connectivity and port availability

#### Package Installation (installation.sh)

- Downloads CheckMk server packages with integrity verification
- Handles server package installation with proper error handling
- Manages CheckMk server setup and configuration
- Provides progress indicators for long operations

#### Site Management (site_management.sh)

- Creates and configures CheckMk monitoring sites
- Manages site passwords securely
- Handles site startup and API readiness
- Provides detailed error diagnostics

#### Host/Folder Management (entity_management.sh)

- Creates monitoring folder hierarchies
- Adds hosts to monitoring with proper configuration
- Prevents duplicate entries
- Handles batch operations efficiently

#### API Operations (api_operations.sh)

- Manages authenticated CheckMk REST API requests
- Handles configuration activation
- Implements retry logic for reliability
- Processes API responses with error handling

#### System Information Collection (system_info.sh)

- Collects comprehensive system state before/after installation
- Generates detailed hardware and software inventories
- Creates troubleshooting data for support purposes
- Organizes information in structured formats

#### Logging and Utilities (common.sh, log_rotation.sh)

- Provides centralized logging with level-based filtering
- Implements log rotation to prevent disk space issues
- Offers visual progress indicators and user feedback
- Handles error reporting with stack traces in debug mode

## Notification Scripts

### Discord Integration (discord.py)

**Purpose**: Sends CheckMk alerts to Discord channels via webhooks.

**Features**:

- State-specific message formatting (OK, WARNING, CRITICAL)
- Duplicate notification prevention
- Customizable message templates
- Color-coded embed messages
- Error logging and state tracking

**Configuration**:

```python
WEBHOOK_URL = "https://discord.com/api/webhooks/your-webhook-url"
STATE_FILE = "/tmp/discord_notification_state.json"
DEDUP_WINDOW = 300  # 5 minutes deduplication window
```

**Message Format**:

- **OK**: Green embed with resolution confirmation
- **WARNING**: Yellow embed with warning details
- **CRITICAL**: Red embed with urgent alert information

### GLPI Integration (glpi.py)

**Purpose**: Automatically creates and manages tickets in GLPI based on CheckMk alerts.

**Features**:

- Automatic ticket creation for CRITICAL states
- Ticket closure when issues are resolved (OK state)
- Proper GLPI API session management
- Configurable ITIL categories and priorities
- State tracking to prevent duplicate tickets

**Configuration**:

```python
GLPI_API_URL = "https://your-glpi-server/apirest.php"
APP_TOKEN = "your-app-token"
USER_TOKEN = "your-user-token"
STATE_FILE = "/tmp/glpi_ticket_state.json"
```

**Workflow**:

1. **CRITICAL Alert**: Creates new ticket with detailed information
2. **WARNING Alert**: Updates existing ticket or creates new one
3. **OK Alert**: Closes open tickets and adds resolution notes

## Usage Examples

### Complete Environment Setup

```bash
# 1. Configure your CheckMk server environment
cd scripts/installation/
cp config.json
# Edit config.json with your specific settings

# 2. Install CheckMk server with host configuration
sudo ./setup.sh --install --add-hosts

# 3. Install agents on monitored hosts
# For Debian hosts: Follow the Debian Monitoring Guide
# For Windows hosts: Follow the Windows Monitoring Guide
```

### Notification Setup

```bash
# 1. Copy notification scripts to CheckMk
sudo cp ../notifications/*.py /opt/omd/sites/monitoring/local/share/check_mk/notifications/

# 2. Make scripts executable
sudo chmod +x /opt/omd/sites/monitoring/local/share/check_mk/notifications/*.py

# 3. Configure webhooks/API tokens in the scripts
sudo nano /opt/omd/sites/monitoring/local/share/check_mk/notifications/discord.py
sudo nano /opt/omd/sites/monitoring/local/share/check_mk/notifications/glpi.py
```

### Configuration Management

The scripts use a centralized JSON configuration approach:

```json
{
  "site_name": "monitoring",
  "checkmk_version": "2.4.0",
  "expected_hash": "1cd25e1831c96871f67128cc87422d2a35521ce42409bad96ea1591acf3df1a4",
  "api_settings": {
    "host": "localhost",
    "port": 80
  },
  "folders": [
    {
      "name": "linux_servers",
      "title": "Linux Servers"
    },
    {
      "name": "windows_servers",
      "title": "Windows Servers"
    }
  ],
  "hosts": [
    {
      "hostname": "debian-host",
      "ipaddress": "192.168.1.100",
      "folder": "linux_servers"
    },
    {
      "hostname": "windows-server",
      "ipaddress": "192.168.1.101",
      "folder": "windows_servers"
    }
  ]
}
```

## Troubleshooting and Diagnostics

### Installation Issues

```bash
# Check installation logs
tail -f scripts/installation/logs/installation_*.log

# Debug mode for detailed output
sudo ./setup.sh --debug --install

# System information collection
sudo ./setup.sh --system-info
```

### Agent Issues

```bash
# Agent diagnostics
sudo ./setup.sh --agent-diagnostics

# Check agent status
sudo systemctl status check-mk-agent
sudo netstat -tlnp | grep 6556
```

### Notification Issues

```bash
# Check notification logs
tail -f /opt/omd/sites/monitoring/var/log/notify.log

# Test notification scripts manually
sudo -u monitoring /opt/omd/sites/monitoring/local/share/check_mk/notifications/discord.py
```

## Best Practices

1. **Configuration Management**: Keep your `config.json` in version control (without sensitive data)
2. **Testing**: Always test in a development environment first
3. **Monitoring**: Monitor the monitoring system itself for recursive issues
4. **Documentation**: Keep local documentation updated with your specific configurations
5. **Backups**: Regular backups of CheckMk configuration and custom scripts
6. **Security**: Use proper file permissions and avoid hardcoding credentials

## Integration with Documentation

These scripts are referenced throughout the documentation:

- **[Installation Guide](./02_InstallationGuide.md)**: Primary reference for setup.sh usage
- **[Configuration Guide](./03_ConfigurationGuide.md)**: Notification script setup and configuration
- **[Monitoring Debian](./04_MonitoringDebian.md)**: Agent installation procedures
- **[Monitoring Windows](./05_MonitoringWindows.md)**: Windows-specific agent setup
- **[Log Management](./06_LogManagement.md)**: Log analysis and troubleshooting procedures
