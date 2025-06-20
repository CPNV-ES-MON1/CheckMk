# CheckMk Notification Scripts

## Overview

This folder contains scripts for integrating CheckMk with different notification platforms. These scripts allow monitoring alerts to be formatted and sent to various communication systems, improving incident visibility and response.

## Repository Structure

```
/notifications/
├── discord.py           # Discord notification integration
└── glpi.py             # GLPI ticket management integration
```

## Available Scripts

### Discord (discord.py)

Script for sending CheckMk notifications to Discord channels using webhooks.

#### Configuration

Edit the script to configure:

- `WEBHOOK_URL`: URL of your Discord channel webhook
- `STATE_FILE`: Location of the state file for notification tracking
- `DEDUP_WINDOW`: Time interval (in seconds) for duplicate prevention

#### Customization

The script includes predefined messages for different states (OK, WARNING, CRITICAL), which can be easily modified:

- **Title**: Notification header
- **Description**: Brief explanation of the issue
- **Details**: More detailed information about the state
- **Footer**: Additional message for action or conclusion
- **Colors**: Green for OK, Yellow for WARNING, Red for CRITICAL

### GLPI (glpi.py)

Script for automatic ticket management in GLPI based on CheckMk alerts.

#### Configuration

Edit the script to configure:

- `GLPI_API_URL`: URL of your GLPI API endpoint
- `APP_TOKEN`: GLPI application token
- `USER_TOKEN`: GLPI user token
- `STATE_FILE`: Location of the state file for ticket tracking

#### Features

- **Automatic Ticket Creation**: Creates tickets for CRITICAL alerts
- **Ticket Management**: Updates existing tickets for WARNING states
- **Ticket Closure**: Automatically closes tickets when issues are resolved (OK state)
- **ITIL Integration**: Properly categorizes tickets with ITIL categories
- **Deduplication**: Prevents duplicate tickets for the same issue
