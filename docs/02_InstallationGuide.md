# CheckMk Installation Guide

This guide provides step-by-step instructions for installing CheckMk 2.4.0 on Ubuntu Server 22.04.

## Prerequisites

Before beginning the installation, ensure you have:

- Ubuntu Server 22.04 LTS installed (See [System Requirements](./01_SystemRequirements.md))
- Root access or sudo privileges
- Internet connectivity

## Automated Installation (Recommended)

We've created a script to automate the CheckMk installation process. This script is located in the `scripts/installation/` directory.

### Prerequisites for Automated Installation

Ensure you have:

- Ubuntu Server 22.04 LTS installed
- Root access or sudo privileges
- Internet connectivity
- Git installed to clone the repository

### Step 1: Download the Installation Scripts

```bash
# Clone the repository
git clone https://github.com/CPNV-ES-MON1/CheckMk.git
cd checkmk/scripts/installation/
```

### Step 2: Configure the Installation

```bash
# Edit the configuration file with your specific settings
nano config.json
```

**Key configuration parameters to modify**:

```json
{
  "site_name": "YOUR_CHECKMK_SERVER",
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

### Step 3: Run the Installation

```bash
# Full installation with host configuration
sudo ./setup.sh --install --add-hosts

# For debug output during installation
sudo ./setup.sh --debug --install --add-hosts
```

### What the Script Does

The automated installation script will:

1. **System Validation**:

   - Verify root privileges and system requirements
   - Install dependencies (jq, curl, wget, lshw)
   - Collect pre-installation system information

2. **Package Management**:

   - Update system packages
   - Download CheckMk package with integrity verification
   - Install CheckMk and dependencies

3. **Site Configuration**:

   - Create monitoring site with secure password generation
   - Start CheckMk services
   - Wait for API readiness

4. **Host Management** (if --add-hosts used):

   - Create folder structure from configuration
   - Add hosts to monitoring
   - Activate configuration changes

5. **Completion**:
   - Display installation summary
   - Provide web interface access information
   - Save logs for troubleshooting

### Installation Output

Upon successful completion, you'll see:

```
=== CheckMk Installation Summary ===
✓ CheckMk 2.4.0 installed successfully
✓ Site 'monitoring' created and started
✓ Web interface available at: http://YOUR_SERVER_IP/monitoring/
✓ Username: cmkadmin
✓ Password: [generated password displayed]
✓ 2 hosts added to monitoring
✓ Configuration activated successfully

Installation completed in XX minutes.
Logs saved to: scripts/installation/logs/installation_YYYYMMDD_HHMMSS.log
```

## Next Steps

After installation, proceed to the [Configuration Guide](./03_ConfigurationGuide.md) to set up your monitoring environment.
