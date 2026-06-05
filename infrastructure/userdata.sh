#!/bin/bash
# =============================================================
# userdata.sh — EC2 Bootstrap Script (Python FastAPI Stack)
# Runs ONCE on first boot only.
# Variables injected by Terraform templatefile()
# Architecture: CloudFront + EC2 origin
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
apt-get install -y curl git unzip wget python3 python3-pip python3-venv unzip

echo "[$(date)] Python version: $(python3 --version)"
echo "[$(date)] Pip version: $(pip3 --version)"

# -----------------------------------------------------------
# INSTALL AWS CLI
# -----------------------------------------------------------
if ! command -v aws &>/dev/null; then
    curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "[$(date)] AWS CLI installed: $(aws --version)"
fi

# -----------------------------------------------------------
# APP DIRECTORY
# -----------------------------------------------------------
APP_DIR="/opt/${project_name}"
mkdir -p "$APP_DIR"

# -----------------------------------------------------------
# DOWNLOAD BACKEND CODE FROM S3
# -----------------------------------------------------------
S3_BUCKET="${project_name}-${environment}-backend-code"
S3_KEY="backend.tar.gz"

if aws s3 ls "s3://$S3_BUCKET/$S3_KEY" >/dev/null 2>&1; then
    echo "[$(date)] Downloading backend code from s3://$S3_BUCKET/$S3_KEY"
    aws s3 cp "s3://$S3_BUCKET/$S3_KEY" "/tmp/$S3_KEY"
    tar -xzf "/tmp/$S3_KEY" -C "$APP_DIR"
    rm -f "/tmp/$S3_KEY"
    echo "[$(date)] Backend code extracted to $APP_DIR"
fi

# -----------------------------------------------------------
# PYTHON VIRTUAL ENVIRONMENT + DEPENDENCIES
# -----------------------------------------------------------
cd "$APP_DIR"

if [ -f "requirements.txt" ]; then
    python3 -m venv "$APP_DIR/venv"
    source "$APP_DIR/venv/bin/activate"
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
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin:/usr/bin"
ExecStart=$APP_DIR/venv/bin/uvicorn app:app --host 0.0.0.0 --port ${app_port}
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
# COMPLETE
# -----------------------------------------------------------
echo "[$(date)] Bootstrap COMPLETE — ${project_name} (${environment}) ready."
echo "[$(date)] API running on port ${app_port}"