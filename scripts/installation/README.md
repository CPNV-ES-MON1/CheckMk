# CheckMk Server Installation and Configuration Tool

## Description

Automated solution for installing and configuring CheckMk monitoring server on Ubuntu/Debian-based systems. This script orchestrates the complete process from system validation to final configuration, including downloading packages, verifying integrity, creating monitoring sites, and configuring hosts and folders from JSON configuration files.

## Project Structure

```
/installation/
├── setup.sh                    # Main installation script
├── config.json                 # Configuration file with all settings
└── lib/                        # Modular library system
    ├── api_operations.sh        # CheckMk REST API interaction and management
    ├── common.sh                # Shared utilities, logging, and progress indicators
    ├── config.sh                # Core configuration constants and defaults
    ├── config_loader.sh         # JSON configuration loading and validation
    ├── entity_management.sh     # Host and folder management operations
    ├── installation.sh          # Package download, verification, and installation
    ├── log_rotation.sh          # Log management and rotation system
    ├── site_management.sh       # CheckMk site creation and management
    ├── system_checks.sh         # System validation and dependency management
    └── system_info.sh           # System information collection for diagnostics
```

## Configuration

### Configuration File (config.json)

The script uses a comprehensive JSON configuration file that defines all aspects of the installation and setup. This file must be present in the same directory as the setup script.

#### Complete Configuration Structure

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
      "name": "production_servers",
      "title": "Production Servers"
    },
    {
      "name": "development_servers",
      "title": "Development Environment"
    },
    {
      "name": "network_infrastructure",
      "title": "Network Infrastructure"
    }
  ],
  "hosts": [
    {
      "hostname": "web-server-01",
      "ipaddress": "192.168.1.10",
      "folder": "production_servers"
    },
    {
      "hostname": "db-server-01",
      "ipaddress": "192.168.1.20",
      "folder": "production_servers"
    },
    {
      "hostname": "dev-server-01",
      "ipaddress": "192.168.2.10",
      "folder": "development_servers"
    }
  ]
}
```

#### Configuration Parameters Detailed

**Core Settings:**

- `site_name`: CheckMk monitoring site identifier (alphanumeric, lowercase recommended)
- `checkmk_version`: Exact CheckMk version to install (e.g., "2.4.0", "2.3.0")
- `expected_hash`: SHA256 hash of the package file for integrity verification

**API Configuration:**

- `api_settings.host`: API hostname/IP address (default: "localhost")
- `api_settings.port`: API port number (default: 80)

**Folder Structure:**

- `folders[].name`: Folder identifier (used in API calls and host assignments)
- `folders[].title`: Human-readable folder display name

**Host Configuration:**

- `hosts[].hostname`: Unique host identifier in CheckMk
- `hosts[].ipaddress`: IP address or hostname for monitoring
- `hosts[].folder`: Must match a folder name defined in the folders section

#### Configuration Validation

The script performs comprehensive validation:

- JSON syntax verification
- Required field presence checking
- Folder/host relationship validation
- Network configuration validation
- Version format verification

### Available Options

```
Usage: sudo setup.sh [OPTION]...

Options:
  --help                 Display comprehensive help message and exit
  --debug                Enable detailed debug output for troubleshooting
  --install              Install CheckMk server and create monitoring site
  --install-agent        Install CheckMk agent on the current system
  --add-hosts            Add hosts and folders from configuration file
```

### Operation Modes

#### Full Installation Mode

```bash
sudo ./setup.sh --install --add-hosts
```

Performs complete CheckMk server installation including:

- System validation and dependency installation
- CheckMk package download and verification
- Server installation and site creation
- Folder and host configuration from JSON
- Configuration activation and verification

#### Server-Only Installation

```bash
sudo ./setup.sh --install
```

Installs CheckMk server without configuring hosts:

- Downloads and installs CheckMk package
- Creates monitoring site with auto-generated password
- Prepares system for future host configuration

#### Host Configuration Only

```bash
sudo ./setup.sh --add-hosts
```

Adds hosts to existing CheckMk installation:

- Validates existing site and API connectivity
- Creates folders from configuration
- Adds hosts with retry logic
- Activates changes and verifies configuration

#### Agent Installation

```bash
sudo ./setup.sh --install-agent
```

Installs CheckMk agent on the current system:

- Detects CheckMk server version automatically
- Downloads compatible agent package
- Installs and configures agent service
- Provides agent status and connectivity information

#### Debug Mode

```bash
sudo ./setup.sh --debug --install --add-hosts
```

Enables comprehensive debug output including:

- Detailed command execution logs
- API request/response debugging
- System state information
- Stack traces for errors
- Performance timing information

### Advanced Usage Examples

#### Combination Operations

```bash
# Install server and agent on same system
sudo ./setup.sh --install --install-agent --add-hosts

# Reinstall agent on existing CheckMk server
sudo ./setup.sh --install-agent

# Add hosts with detailed debugging
sudo ./setup.sh --debug --add-hosts
```

### Local System Connectivity

**CheckMk Web Interface:**

- **HTTP (TCP/80)** or **HTTPS (TCP/443)** on localhost
- Used for web interface access and API communication
- Configurable port via `api_settings.port` in config.json

**CheckMk API Communication:**

- **HTTP (TCP/80)** by default (configurable)
- Used for folder creation, host addition, and configuration activation
- Authentication via Basic Auth with site credentials

**Agent Communication (if installing agent):**

- **TCP/6556** - CheckMk agent listening port
- Used for monitoring data collection
- Must be accessible from CheckMk server to monitored hosts

### Network Security Considerations

**Firewall Configuration:**

- Allow outbound HTTPS (443) for package downloads
- Allow inbound HTTP (80/443) for web interface access
- Allow inbound TCP/6556 for agent communication (if applicable)

**Proxy Support:**

- Script respects system proxy settings via environment variables
- Set `http_proxy`, `https_proxy`, and `no_proxy` if required
- Proxy authentication supported through URL format

## Module Architecture

The installation script uses a modular architecture with 10 specialized library modules, each handling specific aspects of the installation and configuration process.

### Main Script (setup.sh)

**Primary Functions:**

- **Argument Parsing**: Intelligent command-line argument processing with typo detection
- **Operation Orchestration**: Coordinates all installation phases and module interactions
- **Environment Setup**: Initializes logging, loads libraries, and validates prerequisites
- **Error Handling**: Provides comprehensive error recovery and cleanup procedures
- **User Interface**: Displays banners, progress, and installation summaries

### Core Library Modules

#### System Validation (system_checks.sh)

**Purpose**: Ensures system readiness and installs required dependencies.

**Functions:**

- `check_root()`: Verifies root/sudo privileges for system modifications
- `install_dependencies()`: Automatically installs required packages:
  - `jq`: JSON parsing for configuration file processing
  - `curl`: HTTP requests for API communication and downloads
  - `wget`: Package downloads with progress indication
  - `lshw`: Hardware information collection for diagnostics
- `check_site_status()`: Validates CheckMk site operational status
- `check_agent_installed()`: Detects existing CheckMk agent installations
- `get_agent_status()`: Comprehensive agent status checking with WSL support
- `check_api_connectivity()`: Tests API availability with retry logic

**Error Handling:**

- Package installation failure recovery
- Network connectivity validation
- Dependency conflict resolution

#### Configuration Management (config_loader.sh)

**Purpose**: Loads, validates, and processes JSON configuration files.

**Functions:**

- `check_config_files()`: Validates configuration file existence and accessibility
- `load_config()`: Comprehensive JSON parsing and validation
- Configuration parameter extraction with type checking
- Folder/host relationship validation
- API URL construction and validation

**Validation Features:**

- JSON syntax verification with detailed error reporting
- Required field presence checking
- Data type validation (strings, numbers, arrays)
- Cross-reference validation (folder names in host configurations)
- Network configuration validation

**Configuration Processing:**

- Dynamic variable population from JSON
- Default value application for optional settings
- URL template processing for download links
- API endpoint construction

#### Package Management (installation.sh)

**Purpose**: Handles CheckMk package download, verification, and installation.

**Functions:**

- `download_checkmk()`: Intelligent package downloading with progress indication
- `verify_package()`: SHA256 integrity verification with detailed error reporting
- `install_checkmk()`: System package installation with dependency handling
- `install_checkmk_agent()`: Agent package detection, download, and installation
- `update_system_packages()`: System package updates with conflict resolution

**Key Features:**

- **Progressive Download**: Visual progress bars for large package downloads
- **Integrity Verification**: SHA256 hash checking prevents corrupted installations
- **Version Detection**: Automatic CheckMk version detection for agent compatibility
- **Multi-source Agent Detection**: Searches multiple agent package locations
- **Installation Monitoring**: Real-time installation progress with error detection

**Error Recovery:**

- Package download retry logic with different mirrors
- Integrity verification failure handling
- Installation rollback capabilities
- Network timeout handling

#### Site Management (site_management.sh)

**Purpose**: Creates and manages CheckMk monitoring sites with secure password handling.

**Functions:**

- `check_site_exists()`: Verifies existing site presence
- `create_monitoring_site()`: Secure site creation with auto-generated passwords
- `start_monitoring_site()`: Site startup with service validation
- `setup_monitoring_site()`: Complete site setup orchestration
- `wait_for_api_with_spinner()`: API readiness waiting with visual feedback
- `get_site_password()`: Multi-method password retrieval and validation

**Security Features:**

- **Secure Password Handling**: Passwords never stored in plain text logs
- **Password Extraction**: Automatic password capture from site creation output
- **Password Validation**: API connectivity testing with provided credentials
- **Temporary File Management**: Secure cleanup of password-containing files

**Operational Features:**

- Site status monitoring and validation
- API readiness detection with timeout handling
- Interactive password prompting with validation
- Site startup automation with error detection

#### Host and Folder Management (entity_management.sh)

**Purpose**: Manages CheckMk monitoring objects including folders and hosts.

**Functions:**

- `host_exists()`: Checks for existing host configurations
- `check_folder_exists_in_checkmk()`: Validates folder presence in CheckMk
- `create_folder()`: Creates monitoring folders with proper hierarchy
- `add_host()`: Adds hosts to monitoring with comprehensive error handling
- `create_folders_from_config()`: Batch folder creation with optimization
- `add_hosts_from_config()`: Bulk host addition with retry logic

**Advanced Features:**

- **Batch Operations**: Efficient bulk folder and host creation
- **Duplicate Prevention**: Intelligent checking to avoid duplicate entries
- **Retry Logic**: Automatic retry for transient API failures
- **Cache Management**: Local caching for improved performance
- **Relationship Validation**: Ensures hosts are assigned to valid folders

**Error Handling:**

- API timeout handling with exponential backoff
- Invalid folder reference detection and auto-creation
- Host configuration validation with detailed error messages
- Rollback capabilities for failed bulk operations

#### API Operations (api_operations.sh)

**Purpose**: Provides comprehensive CheckMk REST API integration.

**Functions:**

- `make_api_request()`: Generic API request handling with authentication
- `wait_for_api()`: API availability checking with intelligent retry logic
- `activate_changes()`: Configuration change activation with verification
- `force_activation()`: Forced activation for edge cases

**API Features:**

- **Authentication Management**: Secure Basic Auth with base64 encoding
- **Response Processing**: JSON response parsing and error extraction
- **Request Timing**: Performance monitoring and optimization
- **Error Classification**: Intelligent error type detection and handling

**Reliability Features:**

- **Retry Logic**: Configurable retry attempts with backoff
- **Timeout Handling**: Request timeout management
- **Response Validation**: HTTP status code and content validation
- **Connection Testing**: API connectivity verification

#### System Information Collection (system_info.sh)

**Purpose**: Collects comprehensive system information for diagnostics and troubleshooting.

**Functions:**

- `collect_system_info()`: Comprehensive system state collection

**Information Collected:**

- **Package Information**: Complete installed package inventory
- **Network Configuration**: Interface configuration, routing, DNS settings
- **Service Status**: Running services and their states
- **Hardware Information**: CPU, memory, disk, and peripheral details
- **Process Information**: Running processes and resource usage
- **Security Settings**: Firewall rules and access controls

**Diagnostic Features:**

- Pre/post installation snapshots for comparison
- Timeout-protected information collection
- Structured output for automated analysis
- Error-tolerant collection (continues on individual failures)

#### Logging and Utilities (common.sh)

**Purpose**: Provides centralized logging, progress indication, and utility functions.

**Functions:**

- `log()`: Multi-level logging with color-coded output and file logging
- `execute_with_spinner()`: Visual progress indication for long operations
- `execute_task()`: Task execution with comprehensive error handling
- `command_exists()`: Cross-platform command availability checking
- `display_summary()`: Installation summary generation
- `sanitize_password()`: Secure password sanitization for logs

**Logging Features:**

- **Multi-level Logging**: DEBUG, INFO, WARNING, ERROR, SUCCESS levels
- **Color-coded Output**: Visual distinction between log levels
- **File Logging**: Parallel logging to files with rotation
- **Debug Mode**: Detailed debugging information including stack traces
- **Password Sanitization**: Automatic password removal from logs

**Progress Indication:**

- **Spinner Animations**: Visual feedback for long-running operations
- **Progress Bars**: Percentage-based progress for downloads
- **Time Tracking**: Operation duration measurement and reporting
- **User Feedback**: Clear status messages and completion notifications

#### Log Management (log_rotation.sh)

**Purpose**: Manages log files to prevent disk space issues and maintain log history.

**Functions:**

- `setup_log_directory()`: Creates log directories with proper permissions
- `rotate_logs()`: Automatic log rotation with configurable retention
- `create_log_summary()`: Generates executive summaries of installation logs

**Log Management Features:**

- **Automatic Rotation**: Keeps last 30 log files by default
- **Disk Space Protection**: Prevents log files from consuming excessive disk space
- **Permission Management**: Ensures proper log file permissions
- **Summary Generation**: Creates condensed log summaries for quick review
- **Latest Log Linking**: Maintains symbolic links to most recent logs

### Module Interaction Flow

1. **Initialization**: Main script loads all library modules and validates dependencies
2. **Configuration**: Config loader validates and processes JSON configuration
3. **System Preparation**: System checks installs dependencies and validates environment
4. **Package Management**: Installation module downloads and installs CheckMk packages
5. **Site Setup**: Site management creates and configures monitoring sites
6. **API Integration**: API operations module handles CheckMk configuration
7. **Entity Configuration**: Entity management creates folders and adds hosts
8. **Logging**: All operations logged through common utilities module
9. **Cleanup**: Log rotation manages historical logs and cleanup

## Installation Workflows

### Complete Server Installation Workflow

The full installation process follows a carefully orchestrated sequence to ensure reliable CheckMk deployment:

#### Phase 1: System Preparation and Validation

1. **Privilege Verification**:

   - Validates root/sudo access for system modifications
   - Checks user permissions for package installation
   - Verifies write access to system directories

2. **Dependency Resolution**:

   - Updates package repository information
   - Installs required dependencies (`jq`, `curl`, `wget`, `lshw`)
   - Validates dependency versions and compatibility

3. **Configuration Loading**:

   - Parses and validates JSON configuration file
   - Extracts site settings, folder definitions, and host configurations
   - Validates configuration consistency and completeness

4. **Pre-Installation System Snapshot**:
   - Collects comprehensive system information
   - Documents current package installations
   - Records network and service configurations
   - Creates baseline for troubleshooting

#### Phase 2: Package Management

1. **System Package Updates**:

   - Updates system packages with conflict resolution
   - Handles package manager locks and conflicts
   - Applies security updates with minimal disruption

2. **CheckMk Package Download**:

   - Downloads CheckMk package from official repositories
   - Provides real-time download progress indication
   - Handles network interruptions with retry logic
   - Supports proxy configurations and authentication

3. **Package Verification**:
   - Performs SHA256 integrity verification
   - Compares against expected hash from configuration
   - Prevents installation of corrupted packages
   - Provides detailed verification failure diagnostics

#### Phase 3: CheckMk Installation

1. **Package Installation**:

   - Installs CheckMk package with dependency handling
   - Monitors installation progress and error conditions
   - Handles package conflicts and resolution
   - Validates successful installation

2. **Post-Installation Verification**:
   - Verifies CheckMk command availability (`omd`)
   - Checks installed version information
   - Validates system integration
   - Collects post-installation system state

#### Phase 4: Site Configuration

1. **Site Creation**:

   - Creates monitoring site with specified name
   - Generates secure random password for admin user
   - Configures site-specific settings and paths
   - Handles existing site detection and management

2. **Service Startup**:

   - Starts CheckMk site services
   - Validates service startup and operational status
   - Monitors service dependencies and startup sequence
   - Handles startup failures with detailed diagnostics

3. **API Readiness**:
   - Waits for CheckMk API to become available
   - Tests API connectivity and authentication
   - Validates API functionality with test requests
   - Provides timeout handling and retry logic

#### Phase 5: Monitoring Configuration (Optional)

1. **Folder Structure Creation**:

   - Creates monitoring folders from configuration
   - Establishes folder hierarchy and organization
   - Handles folder naming conflicts and validation
   - Optimizes folder creation with batch operations

2. **Host Addition**:

   - Adds hosts to monitoring from configuration
   - Assigns hosts to appropriate folders
   - Validates host configurations and connectivity
   - Implements retry logic for transient failures

3. **Configuration Activation**:
   - Activates all pending configuration changes
   - Validates configuration consistency
   - Handles activation failures with retry logic
   - Provides activation status and verification

#### Phase 6: Completion and Verification

1. **Configuration Verification**:

   - Verifies all hosts are properly configured
   - Checks folder structure and organization
   - Validates monitoring settings and parameters
   - Provides detailed verification reports

2. **Installation Summary**:

   - Displays comprehensive installation summary
   - Provides access URLs and credentials (securely)
   - Lists configured hosts and folders
   - Offers next steps and recommendations

3. **Log Management**:
   - Rotates installation logs to prevent disk space issues
   - Creates log summaries for quick reference
   - Maintains historical installation records
   - Provides troubleshooting information

### Agent Installation Workflow

For environments requiring agent installation on the CheckMk server itself:

#### Agent Detection and Download

1. **Version Detection**:

   - Automatically detects installed CheckMk version
   - Determines compatible agent version requirements
   - Searches multiple agent package locations

2. **Package Acquisition**:
   - Downloads appropriate agent package
   - Verifies package compatibility and integrity
   - Handles download failures with alternative sources

#### Agent Installation and Configuration

1. **Package Installation**:

   - Installs CheckMk agent package
   - Configures agent service and startup
   - Validates agent installation and functionality

2. **Service Configuration**:
   - Enables and starts agent service
   - Configures agent listening port (6556)
   - Validates agent connectivity and responsiveness

### Partial Operation Workflows

#### Host-Only Configuration

For adding hosts to existing CheckMk installations:

1. **Site Validation**:

   - Verifies existing CheckMk site presence
   - Validates site operational status
   - Obtains site credentials for API access

2. **API Connectivity**:

   - Tests CheckMk API availability
   - Validates authentication credentials
   - Establishes secure API session

3. **Configuration Application**:
   - Creates folders if not present
   - Adds hosts with proper folder assignments
   - Activates configuration changes
   - Verifies successful host addition

#### Error Recovery Procedures

**Configuration Failures**:

- Automatic retry logic for transient failures
- Detailed error logging for troubleshooting
- Rollback capabilities for failed operations
- Manual intervention guidance

**Network Issues**:

- Connection timeout handling
- Proxy configuration support
- Alternative download source fallback
- Network connectivity validation

**Permission Problems**:

- Root privilege validation
- File permission checking and correction
- Service access validation
- Security context verification

## Operational Information

### Logging System

**Log Locations**:

- Primary logs: `/var/log/checkmk-setup/`
- Fallback logs: `./logs/` (script directory)
- Latest log link: `/var/log/checkmk-setup/latest.log`

**Log Levels**:

- **DEBUG**: Detailed operation information (enabled with --debug)
- **INFO**: General operation progress and status
- **WARNING**: Non-critical issues that don't stop execution
- **ERROR**: Critical issues that may cause operation failure
- **SUCCESS**: Successful completion confirmations

**Log Rotation**:

- Automatic rotation after 30 log files
- Log summaries created for historical reference
- Disk space protection with automatic cleanup

### Security Considerations

**Password Handling**:

- Auto-generated passwords for site creation
- Secure password extraction and storage
- Password sanitization in logs and output
- Temporary file cleanup for security

**Network Security**:

- HTTPS verification for package downloads
- API authentication with secure credentials
- Firewall consideration documentation
- Proxy support for corporate environments

**File Permissions**:

- Proper log file permissions (644)
- Secure temporary file handling
- Configuration file protection
- Service account security
