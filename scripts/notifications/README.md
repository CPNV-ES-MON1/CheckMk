# CheckMk Notification Scripts

## Overview

This folder contains scripts for integrating CheckMk with different notification platforms. These scripts allow monitoring alerts to be formatted and sent to various communication systems, improving incident visibility and response.

## Repository Structure

```
/notifications/
└──  discord.py           # Discord notification integration
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

## Adding New Notification Scripts

To add a new notification integration:

1. Create a new script in this directory
2. Follow the existing design pattern for consistency:
   - Provide adjustable configurations
   - Implement deduplication when appropriate
   - Use robust error handling
   - Document the message format and usage
