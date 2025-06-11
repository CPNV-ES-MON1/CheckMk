# Monitoring Windows Server 2022

This guide provides step-by-step instructions for setting up monitoring of a Windows Server 2022 host using CheckMk.

## Prerequisites

- CheckMk server installed and configured (see [Installation Guide](./02_InstallationGuide.md))
- Windows Server 2022 host accessible from the CheckMk server
- Administrator access on the Windows host
- Network connectivity on port 6556 (CheckMk agent port)

## MSI Installation

### Step 1: Download the Agent

From the CheckMk web interface:

1. Go to `Setup > Agents > Windows`
2. Download the MSI package for Windows
3. Copy the file to your Windows Server

Or download directly on Windows:

```powershell
# From PowerShell (as Administrator)
Invoke-WebRequest -Uri "http://YOUR_CHECKMK_SERVER/monitoring/check_mk/agents/windows/check_mk_agent.msi" -OutFile "check_mk_agent.msi"
```

### Step 2: Install the Agent

Run as Administrator:

```powershell
# Install the MSI package
msiexec /i check_mk_agent.msi /quiet

# Or with GUI
.\check_mk_agent.msi
```

### Step 3: Verify Installation

Check if the service is running:

```powershell
Get-Service "CheckMK Agent" | Format-Table -AutoSize
Get-NetTCPConnection -LocalPort 6556
```

### Step 4: Configure Windows Firewall

Allow CheckMk agent traffic:

```powershell
# Allow inbound connection on port 6556
New-NetFirewallRule -DisplayName "CheckMK Agent" -Direction Inbound -Protocol TCP -LocalPort 6556 -Action Allow
```

### Step 5: Test Agent Communication

From the CheckMk server, test the connection:

```bash
telnet WINDOWS_HOST_IP 6556
```

## Adding the Host to CheckMk

### Using the Web Interface

1. Go to `Setup > Hosts > Add host`
2. Fill in the host details:
   - **Hostname**: windows-server
   - **IP address**: IP of your Windows host
   - **Folder**: Select appropriate folder
3. Click "Save & go to connection tests"
4. Run the connection test to verify agent communication
5. Click "Save & go to service configuration"
6. Discover and configure services
7. Activate changes

### Using the Configuration Script

If you have the host configured in your `config.json`:

```bash
# From the CheckMk server
cd /path/to/installation/scripts
sudo ./setup.sh --add-hosts
```

## Advanced Configuration

### Custom Performance Counters

Edit the agent configuration file:

```
C:\Program Files (x86)\checkmk\service\check_mk.ini
```

Add custom sections for specific monitoring needs.

## CPU Monitoring Configuration

For the specific CPU monitoring requirements mentioned in the project:

### Step 1: Configure CPU Thresholds

1. Go to `Setup > Service monitoring rules > CPU utilization for simple devices`
2. Create a new rule with these parameters:
   - **Description**: `CPUOver80`
   - **Levels over an extended time period on total CPU utilization**: `80.0%`
   - **Warning after**: `30 secs`
   - **Critical after**: `1 mins`
   - **Explicit Hosts**: `windows-server` (your Windows hostname)

### Step 2: Set Up Notifications

Configure notifications for CPU state changes (see [Configuration Guide](./03_ConfigurationGuide.md) for detailed notification setup).

## Troubleshooting

### Agent Not Responding

1. Check if the CheckMK Agent service is running:

   ```powershell
   Get-Service "CheckMK Agent"
   ```

2. Start the service if needed:

   ```powershell
   Start-Service "CheckMK Agent"
   ```

3. Check if port 6556 is listening:
   ```powershell
   Get-NetTCPConnection -LocalPort 6556
   ```

### Firewall Issues

1. Check Windows Firewall status:

   ```powershell
   Get-NetFirewallProfile | Format-Table Name, Enabled
   ```

2. List firewall rules for CheckMK:

   ```powershell
   Get-NetFirewallRule -DisplayName "*CheckMK*"
   ```

3. Add firewall rule if missing:
   ```powershell
   New-NetFirewallRule -DisplayName "CheckMK Agent" -Direction Inbound -Protocol TCP -LocalPort 6556 -Action Allow
   ```

### Connection Issues

1. Test network connectivity from CheckMk server:

   ```bash
   ping WINDOWS_HOST_IP
   telnet WINDOWS_HOST_IP 6556
   ```

2. Check CheckMk server logs:
   ```bash
   tail -f /opt/omd/sites/monitoring/var/log/nagios.log
   ```

### Performance Issues

1. Check agent performance:

   ```powershell
   # Check agent process resource usage
   Get-Process -Name "check_mk_agent" | Format-Table ProcessName, CPU, WorkingSet
   ```

2. Review agent logs:
   ```
   C:\Program Files (x86)\checkmk\service\check_mk.log
   ```
