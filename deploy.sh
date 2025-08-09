#!/bin/bash

# Palworld Server Local Deployment Script
# This script deploys the Palworld stack to your Hetzner server from your local machine

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration from .env.deploy file
if [[ ! -f ".env.deploy" ]]; then
    print_error ".env.deploy file not found!"
    print_info "Creating .env.deploy template..."
    cat > .env.deploy << 'EOF'
# Hetzner Server Configuration
HETZNER_HOST=your_server_ip
HETZNER_USER=root
HETZNER_DIR=/opt/palworld
SSH_KEY_PATH=~/.ssh/id_rsa

# Palworld Configuration (optional - will use defaults if not set)
TZ=UTC
PUID=1000
PGID=1000
PORT=8211
QUERY_PORT=27015
PLAYERS=16
SERVER_NAME=Afterstory
SERVER_DESCRIPTION=Palworld server named Afterstory
ALLOW_CONNECT_PLATFORM=Steam
MULTITHREADING=true
COMMUNITY=false
RCON_ENABLED=true
RCON_PORT=25575

# Required Secrets (MUST be set)
SERVER_PASSWORD=123
ADMIN_PASSWORD=your_admin_password_here
RWA_PASSWORD=your_web_ui_password_here

# Web UI Configuration (optional)
RWA_HTTP_PORT=4326
RWA_USERNAME=admin
DOZZLE_PORT=9999

# Updates (optional)
WATCHTOWER_SCHEDULE=0 0 4 * * *
EOF
    print_warning "Please edit .env.deploy with your server details and passwords, then run this script again."
    exit 1
fi

# Source the configuration
source .env.deploy

# Validate required variables
if [[ -z "${HETZNER_HOST:-}" || -z "${ADMIN_PASSWORD:-}" || -z "${RWA_PASSWORD:-}" ]]; then
    print_error "Required variables not set in .env.deploy:"
    print_error "HETZNER_HOST, ADMIN_PASSWORD, and RWA_PASSWORD must be configured"
    exit 1
fi

# Expand SSH key path
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

print_info "Starting deployment to ${HETZNER_HOST}..."

# Test SSH connection
print_info "Testing SSH connection..."
if ! ssh -i "${SSH_KEY_PATH}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${HETZNER_USER}@${HETZNER_HOST}" "echo 'SSH connection successful'" >/dev/null 2>&1; then
    print_error "Cannot connect to ${HETZNER_HOST} via SSH"
    print_error "Please check your SSH key path: ${SSH_KEY_PATH}"
    exit 1
fi
print_success "SSH connection established"

# Create remote directory
print_info "Creating remote directory: ${HETZNER_DIR}"
ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${HETZNER_USER}@${HETZNER_HOST}" "mkdir -p ${HETZNER_DIR}"

# Sync repository to server
print_info "Syncing files to server..."
rsync -az --delete \
    --exclude='.git' \
    --exclude='.env.deploy' \
    --exclude='deploy.sh' \
    --exclude='node_modules' \
    --exclude='.DS_Store' \
    -e "ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no" \
    ./ "${HETZNER_USER}@${HETZNER_HOST}:${HETZNER_DIR}/"

print_success "Files synced successfully"

# Deploy on remote server
print_info "Installing Docker and deploying stack..."
ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${HETZNER_USER}@${HETZNER_HOST}" << EOF
set -euo pipefail

# Install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      \$(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker \$USER || true
    echo "Docker installed successfully"
else
    echo "Docker already installed"
fi

cd ${HETZNER_DIR}

# Create .env file from variables
echo "Creating .env file..."
cat > .env << ENVEOF
COMPOSE_PROJECT_NAME=palworld
TZ=${TZ:-UTC}
PUID=${PUID:-1000}
PGID=${PGID:-1000}
PORT=${PORT:-8211}
QUERY_PORT=${QUERY_PORT:-27015}
PLAYERS=${PLAYERS:-16}
SERVER_NAME=${SERVER_NAME:-Afterstory}
SERVER_DESCRIPTION=${SERVER_DESCRIPTION:-Palworld server named Afterstory}
ALLOW_CONNECT_PLATFORM=${ALLOW_CONNECT_PLATFORM:-Steam}
MULTITHREADING=${MULTITHREADING:-true}
COMMUNITY=${COMMUNITY:-false}
RCON_ENABLED=${RCON_ENABLED:-true}
RCON_PORT=${RCON_PORT:-25575}
SERVER_PASSWORD=${SERVER_PASSWORD:-123}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
RWA_HTTP_PORT=${RWA_HTTP_PORT:-4326}
RWA_USERNAME=${RWA_USERNAME:-admin}
RWA_PASSWORD=${RWA_PASSWORD}
DOZZLE_PORT=${DOZZLE_PORT:-9999}
FILEBROWSER_PORT=${FILEBROWSER_PORT:-8080}
ADMIN_PANEL_USER=${ADMIN_PANEL_USER:-admin}
ADMIN_PANEL_PASS=${ADMIN_PANEL_PASS:-palworld123}
DOMAIN=${DOMAIN:-}
EMAIL=${EMAIL:-}
WATCHTOWER_SCHEDULE=${WATCHTOWER_SCHEDULE:-0 0 4 * * *}
ENVEOF

# Create data directory and set permissions
mkdir -p ${HETZNER_DIR}/data/palworld
chown -R 1000:1000 ${HETZNER_DIR}/data || true

# Determine docker compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    echo "ERROR: docker compose not found" >&2
    exit 1
fi

echo "Using: \$COMPOSE"

# Pull latest images and start stack
echo "Pulling latest images..."
\$COMPOSE pull

echo "Starting Palworld stack..."
\$COMPOSE up -d --remove-orphans

# Clean up any problematic containers and restart
echo "Restarting web management services..."
\$COMPOSE stop filebrowser 2>/dev/null || true
\$COMPOSE rm -f filebrowser 2>/dev/null || true

echo "Deployment completed successfully!"
echo ""
echo "Service Status:"
\$COMPOSE ps

echo ""
echo "Access your services at:"
if [ -n "${DOMAIN:-}" ]; then
  echo "- Admin Panel (HTTPS): https://admin.${DOMAIN} (${ADMIN_PANEL_USER:-admin}/${ADMIN_PANEL_PASS:-palworld123})"
  echo "- Live Logs (HTTPS): https://logs.${DOMAIN}"
else
  echo "- Admin Panel: http://${HETZNER_HOST}:${RWA_HTTP_PORT:-4326} (no password - nginx direct)"
  echo "- Live Logs: http://${HETZNER_HOST}:${DOZZLE_PORT:-9999}"
fi
echo "- Game Server: ${HETZNER_HOST}:${PORT:-8211} (password: ${SERVER_PASSWORD:-123})"
echo ""
echo "To view logs: cd ${HETZNER_DIR} && \$COMPOSE logs -f"
EOF

print_success "Deployment completed!"
print_info ""
print_info "Your Palworld server 'Afterstory' is now running!"
print_info ""
print_info "Access URLs:"
if [ -n "${DOMAIN:-}" ]; then
  print_info "- Admin Panel (HTTPS): https://admin.${DOMAIN} (${ADMIN_PANEL_USER:-admin}/${ADMIN_PANEL_PASS:-palworld123})"
  print_info "- Live Logs (HTTPS): https://logs.${DOMAIN}"
  print_info ""
  print_info "SSL certificates will be automatically generated by Let's Encrypt"
else
  print_info "- Admin Panel: http://${HETZNER_HOST}:${RWA_HTTP_PORT:-4326} (no password - nginx direct)"
  print_info "- Live Logs: http://${HETZNER_HOST}:${DOZZLE_PORT:-9999}"
  print_info ""
  print_info "To enable HTTPS, set DOMAIN and EMAIL in .env.deploy"
fi
print_info "- Game Server: ${HETZNER_HOST}:${PORT:-8211} (password: ${SERVER_PASSWORD:-123})"
print_info ""
print_info "To check server status:"
print_info "ssh -i ${SSH_KEY_PATH} ${HETZNER_USER}@${HETZNER_HOST} 'cd ${HETZNER_DIR} && docker compose ps'"
print_info ""
print_info "To view live logs:"
print_info "ssh -i ${SSH_KEY_PATH} ${HETZNER_USER}@${HETZNER_HOST} 'cd ${HETZNER_DIR} && docker compose logs -f'"
