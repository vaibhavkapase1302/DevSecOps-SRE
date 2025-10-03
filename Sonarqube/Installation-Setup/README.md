# SonarQube Installation Guide - Amazon EC2

Complete guide for installing and configuring SonarQube with H2 database on Amazon EC2.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Service Setup](#service-setup)
4. [Access & Configuration](#access--configuration)
5. [Management Commands](#management-commands)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### AWS Requirements
- **Instance Type**: t2.medium or higher (minimum 4GB RAM recommended)
- **OS**: Amazon Linux 2023
- **Storage**: Minimum 20GB

### Security Group Configuration
Open the following ports in your EC2 Security Group:

| Port | Protocol | Purpose |
|------|----------|---------|
| 9000 | TCP | SonarQube Web Interface |
| 22 | TCP | SSH Access |

---

## Installation

### Step 1: Install SonarQube

Create the installation script:

```bash
vi sonarqube_install.sh
chmod +x sonarqube_install.sh
sudo ./sonarqube_install.sh
```

**Installation Script Content:**
```bash
#!/bin/bash

# Minimal SonarQube Setup for Testing/POC
set -e

echo "=== Minimal SonarQube Setup ==="

# Update and install Java 17
echo "Installing Java 17..."
sudo yum update -y
sudo yum install -y java-17-amazon-corretto-headless wget unzip

# Verify Java
java -version

# Create sonarqube user
echo "Creating sonarqube user..."
sudo useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonarqube || true

# Set basic limits
echo "sonarqube soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "sonarqube hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Set vm.max_map_count (essential for Elasticsearch)
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w vm.max_map_count=262144

# Download SonarQube
echo "Downloading SonarQube..."
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.6.0.92116.zip

# Extract and move
echo "Installing SonarQube..."
sudo unzip -q sonarqube-10.6.0.92116.zip -d /opt/
sudo mv /opt/sonarqube-10.6.0.92116 /opt/sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Simple configuration
echo "Configuring SonarQube..."
sudo -u sonarqube tee /opt/sonarqube/conf/sonar.properties << 'EOF'
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

# Create simple start script
sudo tee /opt/sonarqube/start_sonar.sh << 'EOF'
#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
cd /opt/sonarqube
./bin/linux-x86-64/sonar.sh start
EOF

sudo chmod +x /opt/sonarqube/start_sonar.sh
sudo chown sonarqube:sonarqube /opt/sonarqube/start_sonar.sh

# Start SonarQube
echo "Starting SonarQube..."
sudo -u sonarqube /opt/sonarqube/start_sonar.sh

echo ""
echo "=== Setup Complete ==="
echo "SonarQube should be starting up..."
echo "Access: http://YOUR_PUBLIC_IP:9000"
echo "Default login: admin/admin"
```

**What this script does:**
- Installs Java 17 (Amazon Corretto)
- Creates dedicated `sonarqube` user
- Sets required system limits
- Downloads and installs SonarQube 10.6.0
- Configures H2 database (default)
- Starts SonarQube service

---

## Service Setup

### Step 2: Create Systemd Service

Create the service setup script:

```bash
vi create_sonar_service.sh
chmod +x create_sonar_service.sh
sudo ./create_sonar_service.sh
```

**Service Script Content:**
```bash
#!/bin/bash

# Create systemd service for SonarQube
echo "=== Creating SonarQube Systemd Service ==="

# Stop SonarQube if running
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh stop 2>/dev/null || true
sleep 5

# Create systemd service file
sudo tee /etc/systemd/system/sonar.service << 'EOF'
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
ExecReload=/opt/sonarqube/bin/linux-x86-64/sonar.sh restart
User=sonarqube
Group=sonarqube
Restart=on-failure
RestartSec=10
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=5min

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable sonar.service
sudo systemctl start sonar.service

echo "Service created successfully!"
```

**What this does:**
- Creates systemd service file
- Enables auto-start on boot
- Configures automatic restart on failure
- Sets proper resource limits

---

## Access & Configuration

### Initial Access

1. **Get your EC2 Public IP:**
   ```bash
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. **Access SonarQube:**
   - URL: `http://YOUR_PUBLIC_IP:9000`
   - Wait 2-3 minutes for full startup

3. **Default Credentials:**
   - Username: `admin`
   - Password: `admin`

4. **First Login:**
   - You'll be prompted to change the default password
   - **Important:** Change it immediately for security

### Installation Details

| Component | Details |
|-----------|---------|
| **Version** | SonarQube 10.6.0 Community Edition |
| **Database** | H2 (Embedded - for testing/POC) |
| **Java** | OpenJDK 17 (Amazon Corretto) |
| **User** | sonarqube |
| **Installation Path** | /opt/sonarqube |
| **Data Path** | /opt/sonarqube/data |
| **Logs Path** | /opt/sonarqube/logs |

---

## Management Commands

### Service Management

```bash
# Check service status
sudo systemctl status sonar

# Start SonarQube
sudo systemctl start sonar

# Stop SonarQube
sudo systemctl stop sonar

# Restart SonarQube
sudo systemctl restart sonar

# Enable auto-start on boot
sudo systemctl enable sonar

# Disable auto-start on boot
sudo systemctl disable sonar

# View service logs
sudo journalctl -u sonar -f
```

### Manual Management (without systemd)

```bash
# Start manually
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh start

# Stop manually
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh stop

# Restart manually
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh restart

# Check status manually
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh status
```

### Log Management

```bash
# View main SonarQube log
tail -f /opt/sonarqube/logs/sonar.log

# View web server log
tail -f /opt/sonarqube/logs/web.log

# View Elasticsearch log
tail -f /opt/sonarqube/logs/es.log

# View Compute Engine log
tail -f /opt/sonarqube/logs/ce.log

# View all logs
tail -f /opt/sonarqube/logs/*.log
```

### System Checks

```bash
# Check if port 9000 is listening
sudo netstat -tlnp | grep :9000

# Check SonarQube processes
ps aux | grep sonar

# Check Java processes
ps aux | grep java

# Check disk space
df -h /opt/sonarqube

# Check memory usage
free -h
```

---

## Troubleshooting

### SonarQube Won't Start

**Check logs:**
```bash
tail -f /opt/sonarqube/logs/sonar.log
tail -f /opt/sonarqube/logs/es.log
```

**Common issues:**

1. **Insufficient memory:**
   ```bash
   # Check available memory
   free -h
   # Consider upgrading to t2.medium or larger
   ```

2. **vm.max_map_count too low:**
   ```bash
   # Check current value
   sysctl vm.max_map_count
   
   # Set if needed
   sudo sysctl -w vm.max_map_count=262144
   echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
   ```

3. **Port 9000 already in use:**
   ```bash
   # Check what's using port 9000
   sudo lsof -i :9000
   
   # Kill the process if needed
   sudo kill -9 <PID>
   ```

4. **Permission issues:**
   ```bash
   # Fix ownership
   sudo chown -R sonarqube:sonarqube /opt/sonarqube
   
   # Fix permissions
   sudo chmod -R 755 /opt/sonarqube
   ```

### Can't Access Web Interface

1. **Check Security Group:**
   - Ensure port 9000 is open in EC2 Security Group
   - Source: 0.0.0.0/0 or your specific IP

2. **Check if SonarQube is running:**
   ```bash
   sudo systemctl status sonar
   curl http://localhost:9000
   ```

3. **Check firewall (if enabled):**
   ```bash
   sudo firewall-cmd --list-all
   sudo firewall-cmd --permanent --add-port=9000/tcp
   sudo firewall-cmd --reload
   ```

### Service Won't Start Automatically

```bash
# Check if service is enabled
sudo systemctl is-enabled sonar

# Enable if needed
sudo systemctl enable sonar

# Check for errors
sudo systemctl status sonar
sudo journalctl -u sonar -n 50
```

### Performance Issues

1. **Increase JVM memory (for larger projects):**
   ```bash
   sudo vi /opt/sonarqube/conf/sonar.properties
   
   # Add or modify:
   sonar.web.javaOpts=-Xmx1024m -Xms512m
   sonar.ce.javaOpts=-Xmx1024m -Xms512m
   sonar.search.javaOpts=-Xmx1024m -Xms512m
   
   # Restart
   sudo systemctl restart sonar
   ```

2. **Check system resources:**
   ```bash
   top
   htop  # if installed
   iostat  # if installed
   ```

### Database Issues (H2)

**Note:** H2 is for testing/POC only. For production, migrate to PostgreSQL.

```bash
# H2 database location
ls -lh /opt/sonarqube/data/

# Backup H2 database
sudo tar -czf sonarqube-h2-backup-$(date +%Y%m%d).tar.gz /opt/sonarqube/data/

# Reset database (WARNING: Deletes all data)
sudo systemctl stop sonar
sudo rm -rf /opt/sonarqube/data/*
sudo systemctl start sonar
```

---

## Important Notes

### ⚠️ Security Considerations

1. **Change default password immediately** after first login
2. **H2 database is NOT for production** - use PostgreSQL for production
3. **Enable authentication:** Set `sonar.forceAuthentication=true` in `/opt/sonarqube/conf/sonar.properties`
4. **Keep SonarQube updated** for security patches
5. **Restrict Security Group** to specific IPs if possible

### 📝 Production Recommendations

For production environments, consider:
- Using **PostgreSQL** database instead of H2
- Setting up **HTTPS** with SSL certificate
- Implementing **regular backups**
- Using **t2.large** or larger instance type
- Enabling **authentication** and **authorization**
- Setting up **monitoring** and alerts

### 🔄 Upgrade Path

To upgrade SonarQube:
```bash
# Backup first!
sudo systemctl stop sonar
sudo cp -r /opt/sonarqube /opt/sonarqube.backup

# Download new version and extract
# Follow official upgrade guide at docs.sonarqube.org
```

---

## Quick Reference

### File Locations
```
/opt/sonarqube/                 # Installation directory
/opt/sonarqube/conf/            # Configuration files
/opt/sonarqube/data/            # Database files (H2)
/opt/sonarqube/logs/            # Log files
/etc/systemd/system/sonar.service  # Service file
```

### Important URLs
- **SonarQube**: http://YOUR_IP:9000
- **API**: http://YOUR_IP:9000/api
- **Documentation**: https://docs.sonarqube.org

### Support
- **Official Docs**: https://docs.sonarqube.org
- **Community**: https://community.sonarsource.com
- **GitHub**: https://github.com/SonarSource/sonarqube

---

**Installation completed successfully! 🎉**

Access your SonarQube instance at: `http://YOUR_PUBLIC_IP:9000`

Default credentials: `admin/admin` (change immediately!)
