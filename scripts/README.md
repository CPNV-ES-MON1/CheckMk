# CheckMk Installation Script

## Overview

This [script](./install_checkmk.sh) automates the complete process of setting up a CheckMk monitoring environment, including:

- Installing prerequisites
- Downloading and verifying CheckMk packages
- Creating and configuring a monitoring site
- Setting up folder structure
- Adding hosts from configuration
- Activating changes

## Requirements

- Ubuntu/Debian-based system
- Root privileges (must be run with sudo)
- Internet connection
- Properly configured `config.json` file

## Usage

```bash
sudo ./install_checkmk.sh [--debug]
```

### Command Line Options

- `--debug`: Enables verbose debug logging

## Configuration File (config.json)

The script reads all configuration from a `config.json` file, which must be in the same directory as the script.

### Required Fields

| Field             | Description                     | Example                                                              |
| ----------------- | ------------------------------- | -------------------------------------------------------------------- |
| `site_name`       | Name for the CheckMk site       | `"monitoring"`                                                       |
| `checkmk_version` | Version of CheckMk to install   | `"2.4.0"`                                                            |
| `expected_hash`   | SHA256 hash of the package file | `"1cd25e1831c96871f67128cc87422d2a35521ce42409bad96ea1591acf3df1a4"` |
| `folders`         | Array of monitoring folders     | (see below)                                                          |
| `hosts`           | Array of hosts to monitor       | (see below)                                                          |

### Finding Version and Hash Information

To find available versions and their corresponding hash values:

1. Visit the CheckMk download page: [https://checkmk.com/download](https://checkmk.com/download?platform=cmk&distribution=ubuntu&release=jammy&edition=cre)
2. Select the following options:
   - Platform: CheckMk Raw Edition (CRE)
   - Distribution: Ubuntu
   - Release: Jammy (22.04)
   - Version: Select desired version (e.g., 2.4.0)
3. Once selected, the page will display the download link and SHA256 hash
4. Copy the version and hash into your `config.json` file

### Folder Configuration

Each folder in the `folders` array requires:

```json
{
  "name": "folder_name", // Internal name used by CheckMk
  "title": "Display Title" // User-friendly title shown in UI
}
```

### Host Configuration

Each host in the `hosts` array requires:

```json
{
  "hostname": "server1", // Name of the host
  "ipaddress": "192.168.1.100", // IP address for monitoring
  "folder": "folder_name" // Must match a folder name from folders array
}
```

### Complete Example

```json
{
  "site_name": "monitoring",
  "checkmk_version": "2.4.0",
  "expected_hash": "1cd25e1831c96871f67128cc87422d2a35521ce42409bad96ea1591acf3df1a4",
  "folders": [
    {
      "name": "mon_servers",
      "title": "Servers"
    },
    {
      "name": "mon_clients",
      "title": "Clients"
    }
  ],
  "hosts": [
    {
      "hostname": "webserver1",
      "ipaddress": "192.168.1.10",
      "folder": "mon_servers"
    },
    {
      "hostname": "workstation5",
      "ipaddress": "192.168.2.25",
      "folder": "mon_clients"
    }
  ]
}
```

## Features

### System Information Collection

The script collects detailed system information before and after installation:

- Installed packages
- Open ports
- Running services
- Hardware information
- Disk configuration
- Network configuration
- DNS settings
- Process information

This information is stored in `PreInstallationData` and `PostInstallationData` directories.

### API Integration

The script uses CheckMk's API to perform all configuration actions:

- Creating folders
- Adding hosts
- Activating changes

## Security Notes

- The script automatically generates a secure password for the admin user
- The password is displayed at the end of installation - make note of it
- The script runs with root privileges which are required for CheckMk installation
- No external connections are made except to download the CheckMk package
