# CheckMk Configuration Guide

This guide provides step-by-step instructions for configure notifications like suggested in the User Storys

## Activate state change on overload

> Setup > Services monitoring rules > CPU utilization for simple devices : 

**In a new rule set theses parameters :** 

- **Description :** *CPUOver80*
- **[x] Levels over an extended time period on total CPU utilization :** *80.0%*
- **Warning after :** *30 secs (other values to 0)*
- **Critical after :** *1 mins (other values to 0)*
- **[x] Explicit Hosts  :** *<Windows_Workstation_Hostname>*

## Script for discord notification

> CHECK_MK doesn't have a default script made for sending discord notification. So we are forced to use a custom script, using python by default (python is native with check_mk).

```bash
# Go to notifications plugins directory
cd /opt/omd/sites/monitoring/local/share/check_mk/notifications/

# Download the installation script
wget https://raw.githubusercontent.com/your-repo/checkmk/main/Scripts/notifications_discord.py

# Make the script executable
chmod +x notifications_discord.py
```

> The script is a template, you will still need to edit it and enter your discord webhook

The script will:

- Receive state (Critical, OK, Warning)
- Format a notification / message depending on the state
- Use a WebHook URL to send the notification on discord
- Note error messsage in the process in a state file mention as a variable

## Sending notifications on changing state

> Setup > Notifications > Add notification rule : 

**Rule for** ***OK -> WARN*** **state:** 

- **[x]Service events :** *State change -> From OK to WARN*
- **[x]Hosts :** *<Windows_Workstation_Hostname>*
- **[x]Services :** *^CPU\**
- **Send notification :** *discord (script name) -> Select parameters (random parameters)*
- **Select recipient :** *All users*
- **Description :** *CPU - Warning - Windows - discord*

> **!** You must setup the 3 rules needed to manage all different state changes:
- OK -> WARN
- WARN -> CRITICAL
- CRITICAL -> OK
