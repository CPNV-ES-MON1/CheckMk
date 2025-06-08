# Checkmk Performance Analysis & Log Management

## Log Locations & Their Purposes

### WATO (Web Administration Tool)
*Records all configuration changes made via the Web UI.*

```bash
/opt/omd/sites/monitoring/var/check_mk/wato/log/wato_audit.log
```

### General Log Directory

```bash
/opt/omd/sites/<sitename>/var/log/
```

| Log File | Purpose |
|---|---|
| `diskspace.log` | Disk space warnings for the monitoring site |
| `livestatus.log` | Livestatus API queries and real-time monitoring data access |
| `mkeventd.log` | Event Console processing (rules, syslog, SNMP traps, actions) |
| `nagios.log` | Core monitoring engine alerts, service/host state changes |
| `notify.log` | Notification activity (email, SMS, scripts) and delivery results |
| `web.log` | Web UI actions, user activity, configuration changes |
| `apache/access_log` | Web server access logs (HTTP requests) |
| `apache/error_log` | Web server error logs (failed requests, SSL, server issues) |
| `*-error.log` | Error logs for specific Checkmk components |
| `*-access.log` | Access logs for specific Checkmk components |
---

## Log Verification

### Review Logs

Combine all log files into a single file for easier review:

```bash
# Merge all Checkmk logs into one file
sudo find /opt/omd/sites/monitoring/var/log -name "*.log" -exec cat {} + > all_logs_checkmk.txt

# Add WATO audit logs
sudo cat /opt/omd/sites/monitoring/var/check_mk/wato/log/wato_audit.log >> all_logs_checkmk.txt

# Search for critical issues
grep -iE "error|fail|critical|warn" all_logs_checkmk.txt
```

---

## Agent–Server Traffic Analysis

Analyze network traffic between agents and the monitoring server (port 6556 is the default for Checkmk agent communication).

### Linux host sending data
*from monitoring server*
```bash
sudo tcpdump -i any host 10.0.1.11
```

*from linux host*
```bash
sudo tcpdump -i any host 10.0.1.10 and port 6556 -nn -v
```
### Windows host sending data
*From windows host*
```powershell
Get-Content -Path "C:\ProgramData\checkmk\agent\log\check_mk.log" -Wait -Tail 10
```