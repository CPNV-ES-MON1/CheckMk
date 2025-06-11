# CheckMk Configuration Guide

This guide provides step-by-step instructions for configure notifications like suggested in the User Storys

## Activate state change on overload

> Setup > Services monitoring rules > CPU utilization for simple devices :

**In a new rule set theses parameters :**

- **Description :** _CPUOver80_
- **[x] Levels over an extended time period on total CPU utilization :** _80.0%_
- **Warning after :** _30 secs (other values to 0)_
- **Critical after :** _1 mins (other values to 0)_
- **[x] Explicit Hosts :** _<Windows_Workstation_Hostname>_

## Script for discord notification

> CHECK_MK doesn't have a default script made for sending discord notification. So we are forced to use a custom script, using python by default (python is native with check_mk).

```bash
# Go to notifications plugins directory
cd /opt/omd/sites/monitoring/local/share/check_mk/notifications/

# Download the notifications scripts from the repository
# Copy from your local scripts directory:
sudo cp /path/to/checkmk/scripts/notifications/discord.py ./
sudo cp /path/to/checkmk/scripts/notifications/glpi.py ./

# Make scripts executable
chmod +x discord.py
chmod +x glpi.py
```

> Those scripts are templates, you will still need to edit them and enter your Discord webhook URL and your GLPI API tokens

Discord script will:

- Receive state (Critical, OK, Warning)
- Format a notification / message depending on the state
- Use a WebHook URL to send the notification on discord
- Note error messages in the process in a state file mentioned as a variable

GLPI script will:

- Receive state (Critical, OK, Warning)
- Format a notification / message depending on the state
- Use API tokens to open a session and manage a ticket depending on CPU status
- Note error messages in the process in a state file mentioned as a variable

## Discord - Sending notifications on changing state

> Setup > Notifications > Add notification rule :

**Rule for** **_OK -> WARN_** **state:**

- **[x]Service events :** _State change -> From OK to WARN_
- **[x]Hosts :** _<Windows_Workstation_Hostname>_
- **[x]Services :** \*^CPU\*\*
- **Send notification :** _discord.py -> Select parameters (random parameters)_
- **Select recipient :** _All users_
- **Description :** _CPU - Warning - Windows - discord_

> **!** You must setup the 3 rules needed to manage all different state changes:

- OK -> WARN
- WARN -> CRITICAL
- Any -> OK

## GLPI - Sending notifications on changing state

> Setup > Notifications > Add notification rule :

**Rule for** **_OK -> CRIT_** **state:**

- **[x]Service events :** _State change -> From OK to CRIT_
- **[x]Hosts :** _<Windows_Workstation_Hostname>_
- **[x]Services :** \*^CPU\*\*
- **Send notification :** _glpi.py -> Select parameters (random parameters)_
- **Select recipient :** _All users_
- **Description :** _CPU - Warning - Windows - glpi_

> **!** You must setup the 3 rules needed to manage all different state changes:

- OK -> CRITICAL
- CRITICAL -> OK
