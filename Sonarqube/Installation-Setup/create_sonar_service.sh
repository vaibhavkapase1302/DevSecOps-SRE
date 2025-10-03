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
