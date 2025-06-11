# CheckMk Automation Scripts

## Repository Structure

- [**installation/**](./installation/): CheckMk server installation and configuration scripts

  - Complete CheckMk server installation automation
  - Automatic host and folder configuration
  - Site management and API operations
  - Diagnostic and system information tools

- [**notifications/**](./notifications/): Integration scripts for alert systems
  - Custom notifications for various channels (Discord, GLPI)
  - Alert deduplication and formatting
  - Ticket management integration

## Key Features

- **Automated Server Installation**: Complete CheckMk server setup with minimal manual intervention
- **JSON Configuration**: Centralized configuration for easy updates and maintenance
- **Host Management**: Automated host and folder configuration from JSON files
- **Advanced Diagnostics**: Tools for problem identification and resolution
- **Custom Notifications**: Integration with communication platforms for formatted alerts
- **Log Management**: Log rotation and organization for easier troubleshooting

## Important Note

The installation scripts are designed specifically for CheckMk **server** installation and configuration. For agent installation on monitored hosts (Debian, Windows), please refer to the respective monitoring guides in the [docs](../docs/) directory.
