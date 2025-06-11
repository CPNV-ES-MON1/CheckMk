# CheckMk Monitoring Solution

This repository contains documentation and scripts for setting up and configuring CheckMk monitoring.

## Team Members

- Rui Monteiro - rui.monteiro@eduvaud.ch
- Romain Humbert-Droz-Laurent - romain.humbert-droz-laurent@eduvaud.ch
- Nuno Ribeiro Pereira - nuno.ribeiro@eduvaud.ch

## Project Overview

This project implements a comprehensive monitoring solution using CheckMk 2.4.0 running on Ubuntu Server 22.04. The implementation provides automated installation, configuration, and monitoring capabilities for:

- The CheckMk server itself (self-monitoring)
- Debian 12 machines with automated agent deployment and MySQL database monitoring
- Windows Server 2022 machines with agent installation
- Integrated notification systems (Discord, GLPI ticket management)

### Architecture

The solution is deployed on AWS infrastructure with a secure architecture including DMZ access, private network segregation, and comprehensive monitoring coverage. See the [System Requirements](./docs/01_SystemRequirements.md) for the complete architecture diagram.

## Documentation

Detailed documentation is available in the [docs](./docs) directory in the following order:

1. **[System Requirements](./docs/01_SystemRequirements.md)** - Hardware, software requirements, and architecture overview
2. **[Installation Guide](./docs/02_InstallationGuide.md)** - Automated and manual installation procedures
3. **[Configuration Guide](./docs/03_ConfigurationGuide.md)** - CheckMk configuration and notification setup
4. **[Monitoring Debian](./docs/04_MonitoringDebian.md)** - Setting up Debian 12 host monitoring
5. **[Monitoring Windows](./docs/05_MonitoringWindows.md)** - Setting up Windows Server 2022 monitoring
6. **[Log Management](./docs/06_LogManagement.md)** - Log analysis, troubleshooting, and performance monitoring
7. **[Scripts Overview](./docs/07_ScriptsOverview.md)** - Complete documentation of all automation scripts

## Quick Start

### 1. Automated Server Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/CPNV-ES-MON1/CheckMk.git
cd checkmk/scripts/installation/

# Configure your server environment
nano config.json

# Install CheckMk server with host configuration
sudo ./setup.sh --install --add-hosts
```

### 2. Manual Setup

1. Follow the [Installation Guide](./docs/02_InstallationGuide.md) to set up CheckMk server manually
2. Configure your monitoring environment using the [Configuration Guide](./docs/03_ConfigurationGuide.md)
3. Set up monitoring for [Debian](./docs/04_MonitoringDebian.md) and [Windows](./docs/05_MonitoringWindows.md) hosts

## Scripts and Automation

Comprehensive automation scripts are available in the [scripts](./scripts) directory:

### Installation Scripts

- **[setup.sh](./scripts/installation/setup.sh)** - Main automated CheckMk server installation and configuration script
- **[Library modules](./scripts/installation/lib/)** - Modular components for system checks, API operations, site management, and more

### Notification Scripts

- **[discord.py](./scripts/notifications/discord.py)** - Discord webhook integration for alerts
- **[glpi.py](./scripts/notifications/glpi.py)** - GLPI ticket management automation

### Key Features

- **Zero-touch Server Installation**: Complete CheckMk server setup with minimal user intervention
- **Configuration Management**: JSON-based configuration for easy customization
- **Error Handling**: Comprehensive error detection and recovery
- **Logging**: Detailed logging with automatic rotation
- **Host Management**: Automated host and folder configuration from JSON
- **Notification Integration**: Ready-to-use Discord and GLPI integrations
