#!/bin/bash
# Steel Titans Backend Setup Script
# Run on DigitalOcean server as root
# Usage: bash setup_backend.sh

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  Steel Titans Backend Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Variables
API_DIR="/opt/steeltitans/api"
DB_NAME="steeltitans"
DB_USER="steeltitans_api"
DB_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)

echo "📦 Step 1: Installing system dependencies..."
apt-get update
apt-get install -y python3.11 python3.11-venv python3-pip postgresql postgresql-contrib nginx certbot python3-certbot-nginx

echo ""
echo "🐘 Step 2: Setting up PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Create database and user
sudo -u postgres psql <<EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}' 
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
\c ${DB_NAME}
GRANT ALL ON SCHEMA public TO ${DB_USER};
EOF

echo "   Database: ${DB_NAME}"
echo "   User: ${DB_USER}"
echo "   Password: ${DB_PASS}"

echo ""
echo "📁 Step 3: Creating API directory..."
mkdir -p ${API_DIR}
cd ${API_DIR}

echo ""
echo "🐍 Step 4: Setting up Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

echo ""
echo "📥 Step 5: Installing Python dependencies..."
pip install --upgrade pip
pip install fastapi uvicorn[standard] sqlalchemy[asyncio] asyncpg psycopg2-binary python-jose[cryptography] passlib[bcrypt] pydantic-settings python-multipart

echo ""
echo "⚙️ Step 6: Creating environment file..."
cat > ${API_DIR}/.env <<EOF
# Steel Titans API Configuration
# Generated: $(date)

# Database
DATABASE_URL=postgresql+asyncpg://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
DATABASE_SYNC_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}

# Security
SECRET_KEY=${JWT_SECRET}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Server
DEBUG=false
API_HOST=0.0.0.0
API_PORT=8080
ALLOWED_ORIGINS=*
EOF

echo ""
echo "🔧 Step 7: Creating systemd service..."
cat > /etc/systemd/system/steeltitans-api.service <<EOF
[Unit]
Description=Steel Titans API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${API_DIR}
Environment="PATH=${API_DIR}/venv/bin"
EnvironmentFile=${API_DIR}/.env
ExecStart=${API_DIR}/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "🌐 Step 8: Configuring nginx reverse proxy..."
cat > /etc/nginx/sites-available/steeltitans-api <<EOF
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    # Health check endpoint (no /api prefix)
    location /health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF

ln -sf /etc/nginx/sites-available/steeltitans-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo ""
echo "🔥 Step 9: Configuring firewall..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📝 Save these credentials securely:"
echo "   Database: ${DB_NAME}"
echo "   User: ${DB_USER}"
echo "   Password: ${DB_PASS}"
echo "   JWT Secret: ${JWT_SECRET}"
echo ""
echo "📂 API Directory: ${API_DIR}"
echo "🔧 Config File: ${API_DIR}/.env"
echo ""
echo "📤 Next steps:"
echo "   1. Upload API files to ${API_DIR}/"
echo "   2. Run: systemctl daemon-reload"
echo "   3. Run: systemctl enable steeltitans-api"
echo "   4. Run: systemctl start steeltitans-api"
echo ""
echo "🔍 Check status:"
echo "   systemctl status steeltitans-api"
echo "   curl http://localhost:8080/health"
echo ""
