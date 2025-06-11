# CheckMk Server Installation and Configuration Tool

## Overview

Automated solution to install and configure CheckMk monitoring server on Ubuntu/Debian-based environments. It handles the complete process from downloading and verifying the CheckMk package to setting up monitoring sites, configuring folders, and adding hosts to monitoring.

**Important**: This tool is designed for CheckMk **server** installation and configuration. For agent installation on monitored hosts, refer to the respective monitoring guides in the documentation.

### Key Features

- **Complete Server Installation**: Automated CheckMk server setup with site creation
- **Host Management**: Automatic host and folder configuration from JSON files
- **Flexible Configuration**: Folders and hosts configured from JSON files
- **Error Handling**: Robust diagnostic and handling system
- **Detailed Logs**: Log rotation to prevent disk space issues

## Project Structure

```
/installation/
├── setup.sh                # Main installation script
├── config.json             # Configuration file
├── lib/                    # Library modules
│   ├── api_operations.sh     # CheckMk API interaction
│   ├── common.sh             # Common utilities
│   ├── config.sh             # Default settings
│   ├── config_loader.sh      # Configuration loading
│   ├── entity_management.sh  # Folder and host management
│   ├── installation.sh       # Package installation
│   ├── log_rotation.sh       # Log management
│   ├── site_management.sh    # Site management
│   ├── system_checks.sh      # System validation
│   └── system_info.sh        # System information collection
└── logs/                   # Log directory (created if using relative paths)
```

## Configuration

### Configuration File (config.json)

The script uses a JSON configuration file with the following structure:

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
      "name": "example_folder",
      "title": "Folder"
    }
  ],
  "hosts": [
    {
      "hostname": "example_hostname",
      "ipaddress": "0.0.0.0",
      "folder": "example_folder"
    }
  ]
}
```

### Key Configuration Parameters

- `site_name`: Name of the CheckMk monitoring site to create/use
- `checkmk_version`: Version of CheckMk to install (e.g., "2.4.0")
- `expected_hash`: SHA256 hash of the package file for verification
- `api_settings.host`: Hostname/IP for API connections (default: "localhost")
- `api_settings.port`: Port for API connections (default: 80)
- `folders`: List of monitoring folders to create
- `hosts`: List of hosts to add to monitoring

## Command-Line Arguments

```
Usage: sudo setup.sh [OPTION]...

Options:
  --help                 Display help message and exit
  --debug                Enable debug output
  --install              Install CheckMk server and dashboard
  --add-hosts            Add hosts from configuration file
```

### Example Usage

```bash
# Full server installation with host configuration
sudo ./setup.sh --install --add-hosts

# Server installation only
sudo ./setup.sh --install

# Add hosts to an existing site
sudo ./setup.sh --add-hosts

# Enable debug output during installation
sudo ./setup.sh --debug --install
```

```

## Network Requirements

The script uses several network connections:

1. **CheckMk Download**: HTTPS (TCP/443) to download.checkmk.com
2. **CheckMk Web Interface**: HTTP (TCP/80 or configured port) on the local machine
3. **CheckMk API**: HTTP (TCP/80 or configured port) on the local machine
4. **CheckMk Agent**: TCP/6556 for agent communication

### Port Usage

- **80/8080**: Default HTTP port for CheckMk web interface and API
- **6556**: CheckMk agent communication port
- **443**: Used for downloading CheckMk packages

## Module Details

### Main Script (setup.sh)

Orchestrates the entire installation process:

- Parses command-line arguments
- Sets up logging
- Loads configuration
- Performs requested operations
- Provides a summary upon completion

### System Checks (system_checks.sh)

- Verifies root privileges
- Installs dependencies:
  - jq: For JSON parsing
  - curl: For API requests
  - wget: For downloading packages
  - lshw: For system information collection
- Checks site status to ensure proper operation
- Detects existing agent installations

### System Information (system_info.sh)

Collects comprehensive system information before and after installation:

- Installed packages (dpkg --get-selections)
- Open ports (ss -tuln)
- Running services (systemctl)
- Hardware information (lshw)
- Disk information (lsblk)
- Network configuration (ip addr)
- DNS settings (/etc/resolv.conf)
- Process information (ps aux)

### Installation (installation.sh)

Handles the CheckMk package download and installation:

- Downloads the specified CheckMk version
- Verifies package integrity using SHA256 hash
- Installs the package with proper error handling
- Provides detailed progress indication for long operations
- Manages agent installation with automatic version detection

### Site Management (site_management.sh)

Manages CheckMk monitoring sites:

- Creates new sites with secure password handling
- Starts/stops existing sites
- Securely handles site passwords
- Waits for API readiness with user-friendly feedback
- Provides detailed error messages for site issues

### Entity Management (entity_management.sh)

Manages monitoring objects:

- Creates folders with proper hierarchy
- Adds hosts to monitoring
- Verifies object existence to prevent duplicates
- Uses batch operations when possible for efficiency
- Handles API errors with detailed messages

### API Operations (api_operations.sh)

Interacts with CheckMk REST API:

- Makes authenticated API requests
- Handles response processing
- Activates configuration changes
- Implements proper error handling and retries

### Common Utilities (common.sh)

Provides shared functionality:

- Robust logging with level-based filtering
- Visual progress indicators (spinners) for long operations
- Error handling with stack traces in debug mode
- System state information for troubleshooting

### Log Rotation (log_rotation.sh)

Manages log files:

- Creates log directories with proper permissions
- Rotates logs to prevent disk space issues (default: keep 30 logs)
- Creates summary files with key information

## Workflow Details

### Full Server Installation Workflow

1. **Preparation**:

   - Check root privileges
   - Install dependencies
   - Load configuration
   - Collect pre-installation system information

2. **Package Management**:

   - Update system packages
   - Download CheckMk server package
   - Verify package integrity

3. **Installation**:

   - Install CheckMk server package
   - Collect post-installation system information

4. **Site Configuration**:

   - Create monitoring site
   - Wait for API to become ready
   - Create folders from configuration

5. **Host Configuration** (if requested):

   - Add hosts from configuration
   - Activate changes

6. **Completion**:
   - Display installation summary
   - Provide access information

**Note**: For agent installation on monitored hosts, refer to the specific monitoring guides for [Debian](../../docs/04_MonitoringDebian.md) and [Windows](../../docs/05_MonitoringWindows.md) hosts.
```
