#!/bin/bash
# =============================================================
# userdata.sh — EC2 Bootstrap Script (Python FastAPI Stack)
# Runs ONCE on first boot only.
# Variables injected by Terraform templatefile() from variables.tf
# Architecture: CloudFront + EC2 origin (port ${app_port})
# =============================================================
set -euo pipefail

# -----------------------------------------------------------
# LOG SETUP
# -----------------------------------------------------------
exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1
echo "[$(date)] Bootstrap START — Project: ${project_name}, Env: ${environment}"

# -----------------------------------------------------------
# SYSTEM UPDATE + PYTHON
# -----------------------------------------------------------
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git unzip wget python3 python3-pip python3-venv

echo "[$(date)] Python version: $(python3 --version)"
echo "[$(date)] Pip version: $(pip3 --version)"

# -----------------------------------------------------------
# APP DIRECTORY
# -----------------------------------------------------------
APP_DIR="/opt/${project_name}"
mkdir -p "${APP_DIR}"

# -----------------------------------------------------------
# DOWNLOAD BACKEND CODE FROM S3
# -----------------------------------------------------------
S3_BUCKET="${project_name}-${environment}-backend-code"
S3_KEY="backend.tar.gz"

if aws s3 ls "s3://${S3_BUCKET}/${S3_KEY}" >/dev/null 2>&1; then
    echo "[$(date)] Downloading backend code from s3://${S3_BUCKET}/${S3_KEY}"
    aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "/tmp/${S3_KEY}"
    tar -xzf "/tmp/${S3_KEY}" -C "${APP_DIR}"
    rm -f "/tmp/${S3_KEY}"
    echo "[$(date)] Backend code extracted to ${APP_DIR}"
fi

# -----------------------------------------------------------
# PYTHON VIRTUAL ENVIRONMENT + DEPENDENCIES
# -----------------------------------------------------------
cd "${APP_DIR}"

if [ -f "requirements.txt" ]; then
    python3 -m venv "${APP_DIR}/venv"
    source "${APP_DIR}/venv/bin/activate"
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    echo "[$(date)] Python dependencies installed"
else
    echo "[$(date)] WARNING: requirements.txt not found — skipping pip install"
fi

# -----------------------------------------------------------
# SYSTEMD SERVICE — FastAPI via Uvicorn
# -----------------------------------------------------------
cat > "/etc/systemd/system/${project_name}.service" << SERVICEEOF
[Unit]
Description=${project_name} — FastAPI Backend (Port ${app_port})
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin:/usr/bin"
ExecStart=${APP_DIR}/venv/bin/uvicorn app:app --host 0.0.0.0 --port ${app_port}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable "${project_name}.service"
systemctl start "${project_name}.service"

echo "[$(date)] ${project_name} service started (uvicorn :${app_port})"

# -----------------------------------------------------------
# DEPLOYMENT HELPER — upload code from local machine
# -----------------------------------------------------------
cat > "/home/ubuntu/deploy.sh" << 'DEPLOYEOF'
#!/bin/bash
# Usage: Run this on your LOCAL machine (NOT on EC2)
# This uploads the backend code to S3, then SSM into EC2 to redeploy
# First set these variables:
#   PROJECT="cybersec-dashboardq"
#   ENV="production"
#   BUCKET="${PROJECT}-${ENV}-backend-code"
#
# Step 1: Upload code to S3
# cd /path/to/Cybersec-DashboardQ
# tar -czf backend.tar.gz backend/
# aws s3 cp backend.tar.gz s3://${BUCKET}/backend.tar.gz
#
# Step 2: Restart service on EC2 via SSM
# aws ssm send-command \
#   --document-name "AWS-RunShellScript" \
#   --targets "Key=tag:Name,Values=${PROJECT}-backend" \
#   --parameters 'commands=[
#     "cd /opt/'${PROJECT}'",
#     "aws s3 cp s3://'${BUCKET}'/backend.tar.gz /tmp/backend.tar.gz",
#     "tar -xzf /tmp/backend.tar.gz -C /opt/'${PROJECT}'",
#     "rm -f /tmp/backend.tar.gz",
#     "systemctl restart '${PROJECT}'.service"
#   ]'
echo "Run this script on your LOCAL machine with AWS CLI configured."
DEPLOYEOF

chmod +x "/home/ubuntu/deploy.sh"

# -----------------------------------------------------------
# COMPLETE
# -----------------------------------------------------------
echo "[$(date)] Bootstrap COMPLETE — ${project_name} (${environment}) ready."
echo "[$(date)] API running on port ${app_port}"
echo "[$(date)] CloudFront origin will be configured during deployment."