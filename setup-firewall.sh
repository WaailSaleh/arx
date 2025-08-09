#!/bin/bash

# Palworld Server Firewall Setup Script
# Run this on your Hetzner server

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get current SSH connection IP
SSH_CLIENT_IP=$(echo $SSH_CLIENT | cut -d' ' -f1)

print_warning "This script will configure UFW firewall for Palworld server"
print_warning "Your current SSH IP: $SSH_CLIENT_IP"
print_warning "Make sure this is your correct IP or you may lose SSH access!"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

print_info "Installing UFW if not present..."
apt-get update -q
apt-get install -y ufw

print_info "Resetting UFW to defaults..."
ufw --force reset

print_info "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

print_info "Adding inbound rules..."

# SSH access (critical - from your IP only)
ufw allow from $SSH_CLIENT_IP to any port 22 proto tcp comment 'SSH from admin IP'

# Palworld game server (public)
ufw allow 8211/udp comment 'Palworld game server'

# Steam query port (public)
ufw allow 27015/udp comment 'Steam query port'

# RCON Web UI (restricted to admin IP)
ufw allow from $SSH_CLIENT_IP to any port 4326 proto tcp comment 'RCON Web UI'

# Dozzle logs UI (restricted to admin IP)
ufw allow from $SSH_CLIENT_IP to any port 9999 proto tcp comment 'Dozzle logs UI'

print_info "Current UFW rules:"
ufw show added

print_info "Enabling UFW..."
ufw --force enable

print_success "Firewall configured successfully!"
print_info ""
print_info "Inbound rules summary:"
print_info "- SSH (22/tcp): Only from $SSH_CLIENT_IP"
print_info "- Palworld (8211/udp): Public access"
print_info "- Steam Query (27015/udp): Public access"
print_info "- RCON Web (4326/tcp): Only from $SSH_CLIENT_IP"
print_info "- Dozzle (9999/tcp): Only from $SSH_CLIENT_IP"
print_info ""
print_info "Outbound: All traffic allowed (default)"
print_info ""
print_info "To check status: ufw status verbose"
print_info "To add another admin IP: ufw allow from NEW_IP to any port 22,4326,9999 proto tcp"
