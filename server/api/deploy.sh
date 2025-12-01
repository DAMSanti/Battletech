#!/bin/bash
# Deploy script for Steel Titans API
# Run on DigitalOcean server

set -e

echo "🚀 Deploying Steel Titans API..."

# Configuration
API_DIR="/opt/steeltitans/api"
SERVICE_NAME="steeltitans-api"
PYTHON_VERSION="3.11"

# Create directory if not exists
sudo mkdir -p $API_DIR
sudo chown $USER:$USER $API_DIR

# Copy files
echo "📁 Copying files..."
cp -r ./* $API_DIR/

# Create virtual environment
echo "🐍 Setting up Python environment..."
cd $API_DIR
python${PYTHON_VERSION} -m venv venv
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create systemd service
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Steel Titans API
After=network.target postgresql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$API_DIR
Environment="PATH=$API_DIR/venv/bin"
ExecStart=$API_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload and start service
echo "🔄 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

# Check status
echo "✅ Checking service status..."
sudo systemctl status ${SERVICE_NAME} --no-pager

echo ""
echo "🎉 Deployment complete!"
echo "API running at: http://$(hostname -I | awk '{print $1}'):8080"
echo "Health check: curl http://localhost:8080/health"
