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

# Wait and check
echo "Waiting for SonarQube to start..."
sleep 20

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
echo "Check logs if http://localhost:9000 doesn't respond after 5 minutes"
