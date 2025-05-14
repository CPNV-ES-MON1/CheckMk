# CheckMk Installation Guide

This guide provides step-by-step instructions for installing CheckMk 2.4.0 on Ubuntu Server 22.04.

## Prerequisites

Before beginning the installation, ensure you have:

- Ubuntu Server 22.04 LTS installed (See [System Requirements](./01_SystemRequirements.md))
- Root access or sudo privileges
- Internet connectivity

## Installation Methods

There are two ways to install CheckMk:

1. Using our automated installation script
2. Manual installation following step-by-step instructions

## Method 1: Automated Installation

We've created a script to automate the CheckMk installation process.

> WIP

```bash
# Download the installation script
wget https://raw.githubusercontent.com/your-repo/checkmk/main/Scripts/install-checkmk.sh

# Make the script executable
chmod +x install-checkmk.sh

# Run the script with root privileges
sudo ./install-checkmk.sh
```

The script will:

- Collect system information for reference
- Update the system
- Download and verify the CheckMk package
- Install CheckMk and its dependencies
- Create and configure a monitoring site
- Start the CheckMk services

## Method 2: Manual Installation

### Step 1: Collect System Information

```bash
mkdir -p BaseInstallationData && cd BaseInstallationData

# Collecting system information
dpkg --get-selections > packages.txt
sudo ss -tuln > ports.txt
systemctl list-units --type=service --state=running > services.txt
service --status-all > services-status.txt
sudo lshw -short > hardware.txt
sudo lsblk > disks.txt
sudo cp /etc/apt/sources.list sources.list
```

### Step 2: Update System Packages

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 3: Download CheckMk Package

```bash
wget https://download.checkmk.com/checkmk/2.4.0/check-mk-raw-2.4.0_0.jammy_amd64.deb
```

### Step 4: Verify Package Integrity

```bash
# Verify SHA-256 checksum
sha256sum check-mk-raw-2.4.0_0.jammy_amd64.deb
```

Expected output:

```
1cd25e1831c96871f67128cc87422d2a35521ce42409bad96ea1591acf3df1a4  check-mk-raw-2.4.0_0.jammy_amd64.deb
```

### Step 5: Install CheckMk

```bash
sudo apt install ./check-mk-raw-2.4.0_0.jammy_amd64.deb -y
```

### Step 6: Verify Installation

```bash
omd version
```

Expected output:

```
OMD - Open Monitoring Distribution Version 2.4.0.cre
```

### Step 7: Create a Monitoring Site

```bash
sudo omd create monitoring
```

The system will generate a random password for the admin user. Make sure to save this password securely.

### Step 8: Start the Monitoring Site

```bash
sudo omd start monitoring
```

### Step 9: Verify Site Status

```bash
sudo omd status monitoring
```

## Post-Installation

After successful installation:

1. Access the CheckMk web interface at: `http://SERVER_IP/monitoring/`
2. Log in with:
   - Username: `cmkadmin`
   - Password: The password generated during site creation

## Next Steps

After installation, proceed to the [Configuration Guide](./03_ConfigurationGuide.md) to set up your monitoring environment.
