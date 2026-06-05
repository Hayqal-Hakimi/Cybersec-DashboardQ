#!/bin/bash
# =============================================================
# userdata.sh — EC2 Bootstrap Script
# Runs ONCE on first boot only.
# Variables injected by Terraform templatefile() from variables.tf
# Source: AWS Terraform Master Template (Notion) 20-userdata-sh.md
# =============================================================
set -euo pipefail

# -----------------------------------------------------------
# LOG SETUP — all output goes to /var/log/userdata.log
# -----------------------------------------------------------
exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1
echo "[$(date)] Bootstrap START — Project: ${project_name}, Env: ${environment}"

# -----------------------------------------------------------
# SYSTEM UPDATE
# -----------------------------------------------------------
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git unzip wget

# -----------------------------------------------------------
# INSTALL NODE.JS ${nodejs_version} LTS (via NodeSource)
# Official method — NOT apt (apt has stale versions)
# Docs: https://github.com/nodesource/distributions
# -----------------------------------------------------------
curl -fsSL https://deb.nodesource.com/setup_${nodejs_version}.x | bash -
apt-get install -y nodejs
echo "[$(date)] Node.js version: $(node --version)"

# -----------------------------------------------------------
# INSTALL NGINX — reverse proxy to Node.js app
# -----------------------------------------------------------
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# -----------------------------------------------------------
# INSTALL PM2 — process manager (auto-restart on crash)
# -----------------------------------------------------------
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu
systemctl enable pm2-ubuntu

# -----------------------------------------------------------
# INSTALL CLOUDWATCH AGENT — send logs & metrics to AWS
# Docs: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html
# -----------------------------------------------------------
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# -----------------------------------------------------------
# NGINX CONFIG — reverse proxy ke port ${app_port}
# -----------------------------------------------------------
cat > /etc/nginx/sites-available/${project_name} << 'NGINXCONF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINXCONF

ln -sf /etc/nginx/sites-available/${project_name} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# -----------------------------------------------------------
# COMPLETE
# -----------------------------------------------------------
echo "[$(date)] Bootstrap COMPLETE — ${project_name} (${environment}) ready."
