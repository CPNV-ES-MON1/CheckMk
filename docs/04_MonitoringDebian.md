# Monitoring Debian 12

This guide provides step-by-step instructions for setting up monitoring of a Debian 12 host using CheckMk.

## Prerequisites

- CheckMk server installed and configured (see [Installation Guide](./02_InstallationGuide.md))
- Debian 12 host accessible from the CheckMk server
- Network connectivity on port 6556 (CheckMk agent port)
- MySQL/MariaDB installed on the Debian host (if database monitoring is required)

## Agent Installation

### Step 1: Download the Agent

From the CheckMk web interface:

1. Go to `Setup > Agents > Linux`
2. Download the appropriate DEB package for Debian 12

Or using wget directly on the Debian host:

```bash
wget http://YOUR_CHECKMK_SERVER/monitoring/check_mk/agents/check-mk-agent_2.4.0-1_all.deb
```

### Step 2: Install the Agent

```bash
sudo dpkg -i check-mk-agent_2.4.0-1_all.deb
sudo apt-get install -f  # Fix any dependency issues
```

### Step 3: Configure the Agent

The agent runs via xinetd by default. Verify it's running:

```bash
sudo systemctl status xinetd
sudo netstat -tlnp | grep :6556
```

### Step 4: Test Agent Communication

From the CheckMk server, test the connection:

```bash
telnet DEBIAN_HOST_IP 6556
```

You should see agent output.

## MySQL/MariaDB Monitoring Setup

If you have MySQL or MariaDB running on your Debian host, follow these steps to enable database monitoring.

### Step 1: Download MySQL Plugin

Download the MySQL monitoring plugin from your CheckMk server:

```bash
# Replace with your CheckMk server hostname/IP and site name
sudo wget https://YOUR_CHECKMK_SERVER/YOUR_SITE_NAME/check_mk/agents/plugins/mk_mysql -O /usr/lib/check_mk_agent/plugins/mk_mysql
sudo chmod +x /usr/lib/check_mk_agent/plugins/mk_mysql
```

**Example** (using the provided server):

```bash
sudo wget https://checkmk.cld.education/monitoring/check_mk/agents/plugins/mk_mysql -O /usr/lib/check_mk_agent/plugins/mk_mysql
sudo chmod +x /usr/lib/check_mk_agent/plugins/mk_mysql
```

### Step 2: Download MySQL Configuration Template

```bash
sudo mkdir -p /etc/check_mk/
sudo wget https://YOUR_CHECKMK_SERVER/YOUR_SITE_NAME/check_mk/agents/cfg_examples/mysql.cfg -O /etc/check_mk/mysql.cfg
```

**Example**:

```bash
sudo mkdir -p /etc/check_mk/
sudo wget https://checkmk.cld.education/monitoring/check_mk/agents/cfg_examples/mysql.cfg -O /etc/check_mk/mysql.cfg
```

### Step 3: Configure MySQL Plugin

Edit the MySQL configuration file:

```bash
sudo nano /etc/check_mk/mysql.cfg
```

Configure with the following content:

```ini
[client]
user=monitoring
password="your_secure_password"
socket=/var/run/mysqld/mysqld.sock

[check_mk]
aliases=MySQL

!include /etc/check_mk/mysql.local.cfg
```

**Important**: Replace `your_secure_password` with a strong password for the monitoring user.

### Step 4: Create MySQL Monitoring User

Connect to MySQL/MariaDB and create a dedicated monitoring user:

```bash
sudo mysql -u root -p
```

Execute the following SQL commands:

```sql
CREATE USER 'monitoring'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitoring'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

**Security Notes**:

- Use the same password you configured in `/etc/check_mk/mysql.cfg`
- Use a strong, unique password for the monitoring user
- Store the password securely

### Step 5: Test MySQL Monitoring

Test the MySQL plugin manually:

```bash
sudo -u root /usr/lib/check_mk_agent/plugins/mk_mysql
```

You should see MySQL statistics output. If there are errors, check:

- MySQL service is running: `sudo systemctl status mysql`
- Monitoring user can connect: `mysql -u monitoring -p -e "SHOW STATUS;"`
- Configuration file syntax: `sudo cat /etc/check_mk/mysql.cfg`

### Step 6: Restart CheckMk Agent

Restart the agent to pick up the new plugin:

````bash
sudo systemctl restart xinetd

## Adding the Host to CheckMk

### Using the Web Interface

1. Go to `Setup > Hosts > Add host`
2. Fill in the host details:
   - **Hostname**: debian-host
   - **IP address**: IP of your Debian host
   - **Folder**: Select appropriate folder
3. Click "Save & go to connection tests"
4. Run the connection test to verify agent communication
5. Click "Save & go to service configuration"
6. **Discover services** - You should now see MySQL services if the plugin is working correctly
7. Configure discovered services as needed
8. **Activate changes**

### Using the Configuration Script

If you have the host configured in your `config.json`:

```bash
# From the CheckMk server
cd /path/to/installation/scripts
sudo ./setup.sh --add-hosts
````

## Monitoring Services

The CheckMk agent on Debian will automatically monitor:

### Standard System Monitoring

- **System**: CPU, Memory, Disk usage, Load average
- **Network**: Interface statistics and connectivity
- **Processes**: System processes and resource usage
- **Services**: systemd services status
- **Logs**: System logs (if configured)
- **File systems**: Disk space and inode usage

### MySQL/MariaDB Monitoring (if configured)

- **Database Status**: Server status and uptime
- **Performance Metrics**: Queries per second, connections, slow queries
- **Storage**: Database sizes, table statistics
- **Replication**: Master/slave status (if applicable)
- **InnoDB**: Buffer pool usage, lock statistics
- **Connection Monitoring**: Active connections, thread usage

## Troubleshooting

### Agent Not Responding

1. Check if xinetd is running:

   ```bash
   sudo systemctl status xinetd
   ```

2. Check if port 6556 is open:

   ```bash
   sudo netstat -tlnp | grep :6556
   ```

3. Check firewall settings:
   ```bash
   sudo ufw status
   # If needed, allow the port:
   sudo ufw allow 6556
   ```

### Connection Issues

1. Test network connectivity:

   ```bash
   ping CHECKMK_SERVER_IP
   ```

2. Test agent output locally:

   ```bash
   check_mk_agent
   # or
   telnet localhost 6556
   ```

3. Check CheckMk server logs:
   ```bash
   tail -f /opt/omd/sites/monitoring/var/log/nagios.log
   ```
