# SonarQube Installation, Backup & Restore Guide

Complete guide for installing SonarQube on Amazon EC2, setting up HTTPS with NGINX, and restoring from backup.

---

## Table of Contents

1. [Fresh Installation](#fresh-installation)
2. [Systemd Service Setup](#systemd-service-setup)
3. [Backup & Restore](#backup--restore)
4. [HTTPS Setup with NGINX](#https-setup-with-nginx)
5. [Management & Troubleshooting](#management--troubleshooting)
6. [Maintenance & Best Practices](#maintenance--best-practices)

---

## Fresh Installation

### Prerequisites

#### AWS Requirements
- **Instance Type**: t2.medium or higher (4GB RAM minimum)
- **OS**: Amazon Linux 2023
- **Storage**: Minimum 20GB
- **Elastic IP**: Recommended for production

#### Security Group Configuration

| Port | Protocol | Purpose | Required For |
|------|----------|---------|--------------|
| 22 | TCP | SSH Access | Management |
| 80 | TCP | HTTP | SSL Certificate & Redirect |
| 443 | TCP | HTTPS | Secure Access |
| 9000 | TCP | SonarQube Direct | Optional (if not using NGINX) |

### Installation Script

**File: `sonarqube_install.sh`**

```bash
#!/bin/bash

# Minimal SonarQube Setup for Testing/POC
# Quick and simple installation with H2 database

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

# Get IPs
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "localhost")

echo ""
echo "=== Setup Complete ==="
echo "SonarQube should be starting up..."
echo "Access: http://${PUBLIC_IP}:9000 (if security group allows port 9000)"
echo "Local: http://${PRIVATE_IP}:9000"
echo "Default login: admin/admin"
echo ""
echo "Commands:"
echo "- Check if running: sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh status"
echo "- View logs: tail -f /opt/sonarqube/logs/sonar.log"
echo "- Stop: sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh stop"
echo "- Restart: sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh restart"
echo ""
echo "Note: SonarQube takes 2-3 minutes to fully start up"
```

### Installation Steps

```bash
# 1. Upload script to EC2
scp -i your-key.pem sonarqube_install.sh ec2-user@YOUR_IP:~/

# 2. Connect to EC2
ssh -i your-key.pem ec2-user@YOUR_IP

# 3. Run installation
chmod +x sonarqube_install.sh
sudo ./sonarqube_install.sh

# 4. Wait 2-3 minutes and access
# http://YOUR_IP:9000
# Login: admin/admin
```

---

## Systemd Service Setup

### Service Creation Script

**File: `create_sonar_service.sh`**

```bash
#!/bin/bash

# Create systemd service for SonarQube

echo "=== Creating SonarQube Systemd Service ==="

# Stop SonarQube if running
echo "Stopping any running SonarQube instance..."
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh stop 2>/dev/null || true
sleep 5

# Create systemd service file
echo "Creating systemd service file..."
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

# Reload systemd to recognize new service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable service to start on boot
echo "Enabling SonarQube service..."
sudo systemctl enable sonar.service

# Start the service
echo "Starting SonarQube service..."
sudo systemctl start sonar.service

# Wait for service to initialize
echo "Waiting for SonarQube to start..."
sleep 30

# Check service status
echo ""
echo "=== SonarQube Service Status ==="
sudo systemctl status sonar.service --no-pager

echo ""
echo "=== Service Created Successfully ==="
echo ""
echo "Service commands:"
echo "  Start:   sudo systemctl start sonar"
echo "  Stop:    sudo systemctl stop sonar"
echo "  Restart: sudo systemctl restart sonar"
echo "  Status:  sudo systemctl status sonar"
echo "  Logs:    sudo journalctl -u sonar -f"
echo ""
echo "SonarQube will now start automatically on system boot."
```

### Setup Steps

```bash
# Create and run service setup
vi create_sonar_service.sh
chmod +x create_sonar_service.sh
sudo ./create_sonar_service.sh

# Verify service
sudo systemctl status sonar
```

---

## Backup & Restore

### Creating a Backup

#### Manual Backup Method

```bash
# Stop SonarQube
sudo systemctl stop sonar

# Create backup with timestamp
BACKUP_NAME="sonarqube_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
sudo tar -czf ~/$BACKUP_NAME /opt/sonarqube/data /opt/sonarqube/conf

# Start SonarQube
sudo systemctl start sonar

# Download backup to local machine
# From your local machine:
scp -i your-key.pem ec2-user@YOUR_IP:~/$BACKUP_NAME ./
```

#### What Gets Backed Up

```
/opt/sonarqube/data/
├── sonar.mv.db          # H2 Database (users, projects, analysis)
├── es8/                 # Elasticsearch indices
└── web/                 # Web cache

/opt/sonarqube/conf/
└── sonar.properties     # Configuration
```

### Restoring from Backup

#### Pre-Restoration Checklist

**File: `precheck.sh`**

```bash
#!/bin/bash

echo "=========================================="
echo "SonarQube Restoration Pre-Check"
echo "=========================================="
echo ""

# Check 1: Backup file
echo "[1/5] Checking backup file..."
BACKUP_FILE="sonarqube_backup_YYYYMMDD_HHMMSS.tar.gz"  # Update filename
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h $BACKUP_FILE | cut -f1)
    echo "✓ Backup file found (Size: ${SIZE})"
else
    echo "✗ Backup file NOT found"
    echo "  Upload it with: scp -i key.pem $BACKUP_FILE ec2-user@IP:~/"
    exit 1
fi

# Check 2: DNS Configuration
echo ""
echo "[2/5] Checking DNS configuration..."
DOMAIN="your-domain.com"  # Update domain
RESOLVED_IP=$(dig +short $DOMAIN 2>/dev/null | tail -1)
EXPECTED_IP="YOUR_ELASTIC_IP"  # Update IP
if [ "$RESOLVED_IP" = "$EXPECTED_IP" ]; then
    echo "✓ DNS correctly points to $EXPECTED_IP"
else
    echo "⚠️  DNS resolves to: ${RESOLVED_IP:-NOT RESOLVED}"
    echo "  Expected: $EXPECTED_IP"
fi

# Check 3: Ports
echo ""
echo "[3/5] Checking required ports..."
for port in 80 443; do
    if sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  Port $port already in use"
    else
        echo "✓ Port $port available"
    fi
done

# Check 4: SonarQube
echo ""
echo "[4/5] Checking SonarQube installation..."
if [ -d "/opt/sonarqube" ]; then
    echo "✓ SonarQube installed"
else
    echo "✗ SonarQube not found"
    exit 1
fi

# Check 5: Disk space
echo ""
echo "[5/5] Checking disk space..."
AVAILABLE=$(df -h /opt | tail -1 | awk '{print $4}')
echo "Available space in /opt: ${AVAILABLE}"

echo ""
echo "=========================================="
echo "✓ Pre-check complete!"
echo "=========================================="
```

#### Restoration Script

**File: `restore_sonarqube.sh`**

```bash
#!/bin/bash

# Proper restoration of SonarQube data from backup

BACKUP_FILE="sonarqube_backup_YYYYMMDD_HHMMSS.tar.gz"  # UPDATE THIS

echo "=========================================="
echo "SonarQube Data Restoration"
echo "=========================================="

# Step 1: Verify backup
echo "[1/5] Checking backup contents..."
if tar -tzf $BACKUP_FILE | grep -q "sonarqube/data/sonar.mv.db"; then
    echo "✓ Found database in backup"
else
    echo "ERROR: No database found in backup!"
    exit 1
fi

# Step 2: Stop SonarQube
echo ""
echo "[2/5] Stopping SonarQube..."
sudo systemctl stop sonar
sleep 10

# Verify stopped
if pgrep -f "sonarqube" > /dev/null; then
    sudo pkill -9 -f sonarqube
    sleep 5
fi

# Step 3: Backup current data
echo ""
echo "[3/5] Backing up current data..."
BACKUP_DIR="/opt/sonarqube/data.backup_$(date +%Y%m%d_%H%M%S)"
sudo mv /opt/sonarqube/data $BACKUP_DIR
echo "Current data moved to: $BACKUP_DIR"

# Step 4: Extract backup
echo ""
echo "[4/5] Extracting data from backup..."

TEMP_DIR=$(mktemp -d)
tar -xzf $BACKUP_FILE -C $TEMP_DIR sonarqube/data/

sudo mv $TEMP_DIR/sonarqube/data /opt/sonarqube/
rm -rf $TEMP_DIR

sudo chown -R sonarqube:sonarqube /opt/sonarqube/data

echo "✓ Data restored"
echo "Database file:"
sudo ls -lh /opt/sonarqube/data/sonar.mv.db

# Step 5: Start SonarQube
echo ""
echo "[5/5] Starting SonarQube..."
sudo systemctl start sonar

echo "Waiting for startup (2-3 minutes)..."
for i in {1..20}; do
    sleep 10
    if curl -s http://localhost:9000/api/system/status 2>/dev/null | grep -q "UP"; then
        echo "✓ SonarQube started successfully!"
        break
    fi
    echo "Still starting... ($((i*10)) seconds)"
done

echo ""
echo "=========================================="
echo "✓ Restoration Complete!"
echo ""
echo "Try logging in with your old credentials"
echo "=========================================="
```

#### Restoration Steps

```bash
# 1. Upload backup to new EC2
scp -i key.pem sonarqube_backup_YYYYMMDD_HHMMSS.tar.gz ec2-user@NEW_IP:~/

# 2. Connect to EC2
ssh -i key.pem ec2-user@NEW_IP

# 3. Run pre-check (optional)
chmod +x precheck.sh
./precheck.sh

# 4. Update backup filename in restore script
vi restore_sonarqube.sh
# Change BACKUP_FILE variable to your actual filename

# 5. Run restoration
chmod +x restore_sonarqube.sh
sudo ./restore_sonarqube.sh

# 6. Verify
# Access your SonarQube and login with old credentials
```

---

## HTTPS Setup with NGINX

### Prerequisites

1. Domain name configured (A record pointing to Elastic IP)
2. Ports 80 and 443 open in Security Group
3. SonarQube installed and running

### NGINX SSL Setup Script

**File: `setup_nginx_ssl.sh`**

```bash
#!/bin/bash

# NGINX and SSL Setup for SonarQube

DOMAIN="your-domain.com"      # UPDATE THIS
EMAIL="your-email@email.com"  # UPDATE THIS

echo "=========================================="
echo "NGINX SSL Setup for SonarQube"
echo "Domain: $DOMAIN"
echo "=========================================="

# Install NGINX and Certbot
echo "[1/4] Installing NGINX and Certbot..."
sudo yum install -y nginx python3-certbot-nginx

# Update SonarQube to listen on localhost only
echo "[2/4] Configuring SonarQube..."
sudo -u sonarqube tee /opt/sonarqube/conf/sonar.properties << 'EOF'
sonar.web.host=127.0.0.1
sonar.web.port=9000
sonar.forceAuthentication=true
EOF

# Create NGINX configuration
echo "[3/4] Creating NGINX configuration..."
sudo tee /etc/nginx/conf.d/sonarqube.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /api/push {
        proxy_pass http://127.0.0.1:9000/api/push;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Test and start NGINX
sudo nginx -t
sudo systemctl start nginx
sudo systemctl enable nginx

# Restart SonarQube
sudo systemctl restart sonar
sleep 30

# Setup SSL
echo "[4/4] Setting up SSL certificate..."
echo "Checking DNS..."
RESOLVED_IP=$(dig +short $DOMAIN | tail -1)
echo "Domain resolves to: $RESOLVED_IP"

sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

if [ $? -eq 0 ]; then
    echo "✓ SSL certificate installed!"
    sudo systemctl enable certbot-renew.timer
    sudo systemctl start certbot-renew.timer
    
    echo ""
    echo "=========================================="
    echo "✓ Setup Complete!"
    echo ""
    echo "Access: https://$DOMAIN"
    echo "HTTP will redirect to HTTPS"
    echo ""
    echo "SSL auto-renewal enabled"
    echo "=========================================="
else
    echo "⚠️  SSL setup failed"
    echo "But HTTP access works: http://$DOMAIN"
    echo ""
    echo "Retry with: sudo certbot --nginx -d $DOMAIN --email $EMAIL"
fi
```

### Setup Steps

```bash
# 1. Update script with your domain and email
vi setup_nginx_ssl.sh

# 2. Run setup
chmod +x setup_nginx_ssl.sh
sudo ./setup_nginx_ssl.sh

# 3. Verify
curl -I https://your-domain.com
```

---

## Management & Troubleshooting

### Service Management

```bash
# Start SonarQube
sudo systemctl start sonar

# Stop SonarQube
sudo systemctl stop sonar

# Restart SonarQube
sudo systemctl restart sonar

# Check status
sudo systemctl status sonar

# Enable auto-start
sudo systemctl enable sonar

# View logs
sudo journalctl -u sonar -f
```

### Log Files

```bash
# Main SonarQube log
sudo tail -f /opt/sonarqube/logs/sonar.log

# Web server log
sudo tail -f /opt/sonarqube/logs/web.log

# Elasticsearch log
sudo tail -f /opt/sonarqube/logs/es.log

# Compute Engine log
sudo tail -f /opt/sonarqube/logs/ce.log

# All logs
sudo tail -f /opt/sonarqube/logs/*.log
```

### NGINX Management

```bash
# Check NGINX status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart NGINX
sudo systemctl restart nginx

# View NGINX logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### SSL Certificate Management

```bash
# Check certificates
sudo certbot certificates

# Renew certificate manually
sudo certbot renew

# Test auto-renewal
sudo certbot renew --dry-run

# Revoke certificate
sudo certbot revoke --cert-name your-domain.com
```

### Common Issues & Solutions

#### SonarQube Won't Start

```bash
# Check logs
sudo tail -100 /opt/sonarqube/logs/sonar.log

# Check if process is running
ps aux | grep sonar

# Check memory
free -h

# Check vm.max_map_count
sysctl vm.max_map_count
# Should be at least 262144

# Set if needed
sudo sysctl -w vm.max_map_count=262144
```

#### Port Already in Use

```bash
# Check what's using port 9000
sudo lsof -i :9000

# Kill the process
sudo kill -9 <PID>

# Or change SonarQube port in sonar.properties
```

#### Database Issues

```bash
# Check database file
sudo ls -lh /opt/sonarqube/data/sonar.mv.db

# Check ownership
sudo chown -R sonarqube:sonarqube /opt/sonarqube/data

# If corrupted, restore from backup
sudo systemctl stop sonar
sudo mv /opt/sonarqube/data/sonar.mv.db /opt/sonarqube/data/sonar.mv.db.corrupted
# Restore from backup
sudo systemctl start sonar
```

#### SSL Certificate Issues

```bash
# Check certificate expiry
sudo certbot certificates

# Force renewal
sudo certbot renew --force-renewal

# If DNS issues
dig your-domain.com
# Should point to your Elastic IP

# Check NGINX configuration
sudo nginx -t
```

#### Authentication Failed After Restore

```bash
# Check web server logs
sudo tail -100 /opt/sonarqube/logs/web.log

# Verify database was restored
sudo ls -lh /opt/sonarqube/data/sonar.mv.db

# Check if using correct backup
# Old database should be smaller/different than fresh install

# If still issues, check SonarQube status
curl http://localhost:9000/api/system/status
```

### System Checks

```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check running processes
ps aux | grep -E 'java|sonar'

# Check port listeners
sudo netstat -tlnp | grep -E ':(9000|9001|80|443)'

# Check system limits
ulimit -a

# Check SonarQube user limits
sudo -u sonarqube ulimit -a
```

---

## Maintenance & Best Practices

### Regular Backups

Create a backup script that runs automatically:

**File: `/opt/scripts/backup_sonarqube.sh`**

```bash
#!/bin/bash

BACKUP_DIR="/backup/sonarqube"
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR

# Stop SonarQube
systemctl stop sonar

# Create backup
BACKUP_NAME="sonarqube_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf $BACKUP_DIR/$BACKUP_NAME /opt/sonarqube/data /opt/sonarqube/conf

# Start SonarQube
systemctl start sonar

# Remove old backups
find $BACKUP_DIR -name "sonarqube_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup created: $BACKUP_NAME"
```

Setup cron job:

```bash
sudo mkdir -p /opt/scripts
sudo vi /opt/scripts/backup_sonarqube.sh
sudo chmod +x /opt/scripts/backup_sonarqube.sh

# Add to crontab (runs daily at 2 AM)
sudo crontab -e
# Add line:
0 2 * * * /opt/scripts/backup_sonarqube.sh >> /var/log/sonarqube_backup.log 2>&1
```

### Security Checklist

- [ ] Change default admin password
- [ ] Enable force authentication (`sonar.forceAuthentication=true`)
- [ ] Use HTTPS (SSL certificate)
- [ ] Restrict Security Group to specific IPs
- [ ] Regular backups configured
- [ ] SSL auto-renewal enabled
- [ ] Keep SonarQube updated
- [ ] Monitor logs for suspicious activity
- [ ] Use PostgreSQL for production (not H2)

### Performance Tuning

For larger projects, increase JVM memory:

**Edit `/opt/sonarqube/conf/sonar.properties`:**

```properties
# Web Server
sonar.web.javaOpts=-Xmx1024m -Xms512m

# Compute Engine
sonar.ce.javaOpts=-Xmx1024m -Xms512m

# Elasticsearch
sonar.search.javaOpts=-Xmx1024m -Xms1024m
```

### Monitoring

```bash
# Check SonarQube status via API
curl http://localhost:9000/api/system/status

# Monitor resource usage
htop

# Check logs for errors
sudo grep -i error /opt/sonarqube/logs/*.log

# Monitor SSL expiry
sudo certbot certificates | grep "Expiry Date"
```

### Upgrading SonarQube

```bash
# 1. Backup first!
sudo /opt/scripts/backup_sonarqube.sh

# 2. Stop SonarQube
sudo systemctl stop sonar

# 3. Download new version
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-NEW_VERSION.zip

# 4. Extract and move (preserve data)
sudo unzip sonarqube-NEW_VERSION.zip -d /opt/
sudo cp -r /opt/sonarqube/data /opt/sonarqube-NEW_VERSION/
sudo cp -r /opt/sonarqube/conf /opt/sonarqube-NEW_VERSION/

# 5. Backup old version
sudo mv /opt/sonarqube /opt/sonarqube.old

# 6. Move new version
sudo mv /opt/sonarqube-NEW_VERSION /opt/sonarqube

# 7. Fix ownership
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# 8. Start and check logs
sudo systemctl start sonar
sudo tail -f /opt/sonarqube/logs/sonar.log
```

---

## File Locations Reference

```
/opt/sonarqube/                           # Installation directory
├── bin/linux-x86-64/sonar.sh            # Start/stop script
├── conf/sonar.properties                 # Configuration
├── data/                                 # Database and data
│   ├── sonar.mv.db                      # H2 database
│   └── es8/                             # Elasticsearch indices
├── logs/                                 # Log files
│   ├── sonar.log                        # Main log
│   ├── web.log                          # Web server log
│   ├── ce.log                           # Compute Engine log
│   └── es.log                           # Elasticsearch log
└── temp/                                 # Temporary files

/etc/systemd/system/sonar.service        # Systemd service file
/etc/nginx/conf.d/sonarqube.conf         # NGINX configuration
/etc/letsencrypt/live/DOMAIN/            # SSL certificates
/var/log/nginx/                          # NGINX logs
```

---

## Quick Command Reference

### Installation
```bash
# Install SonarQube
sudo ./sonarqube_install.sh

# Create service
sudo ./create_sonar_service.sh

# Setup NGINX SSL
sudo ./setup_nginx_ssl.sh
```

### Service Management
```bash
sudo systemctl {start|stop|restart|status} sonar
sudo systemctl {start|stop|restart|status} nginx
sudo journalctl -u sonar -f
```

### Backup & Restore
```bash
# Create backup
sudo tar -czf backup.tar.gz /opt/sonarqube/data

# Restore backup
sudo systemctl stop sonar
sudo rm -rf /opt/sonarqube/data
sudo tar -xzf backup.tar.gz -C /
sudo chown -R sonarqube:sonarqube /opt/sonarqube/data
sudo systemctl start sonar
```

### SSL Management
```bash
sudo certbot certificates
sudo certbot renew
sudo certbot renew --dry-run
```

### Logs
```bash
sudo tail -f /opt/sonarqube/logs/sonar.log
sudo tail -f /opt/sonarqube/logs/web.log
sudo tail -f /var/log/nginx/error.log
```

---

## Support Resources

- **Official Documentation**: https://docs.sonarqube.org
- **Community Forum**: https://community.sonarsource.com
- **GitHub**: https://github.com/SonarSource/sonarqube
- **Status Page**: https://status.sonarsource.com

---

## Important Notes

### Production Considerations

**H2 Database Limitations:**
- H2 is for testing/POC only
- Not recommended for production
- Cannot scale for large teams
- Limited backup/restore options

**For Production:**
- Use PostgreSQL database
- Use t2.large or larger instance
- Configure regular backups
- Set up monitoring and alerts
- Use dedicated SSL certificate
- Implement access controls

### Version Information

This guide is based on:
- **SonarQube**: 10.6.0 Community Edition
- **Java**: OpenJDK 17 (Amazon Corretto)
- **OS**: Amazon Linux 2023
- **NGINX**: Latest stable
- **Certbot**: Latest stable

---

## Changelog

### 2025-10-03
- Added complete backup and restore procedures
- Added NGINX SSL setup with Let's Encrypt
- Added troubleshooting section
- Added maintenance and monitoring guidelines

---

**End of Guide**

For questions or issues, refer to the troubleshooting section or consult the official SonarQube documentation.
