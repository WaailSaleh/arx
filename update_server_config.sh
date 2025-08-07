#!/bin/bash

# Update Palworld Server Configuration
# This script updates the server with new name, password, and public lobby settings

SERVER_IP="5.161.194.188"
SERVER_USER="palworld"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Updating Palworld server configuration..."

# Stop the server
print_status "Stopping server..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/palworld-server && sudo docker compose down"

# Upload the updated docker-compose.yml
print_status "Uploading new configuration..."
scp docker-compose.yml $SERVER_USER@$SERVER_IP:/opt/palworld-server/

# Start the server with new configuration
print_status "Starting server with new configuration..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/palworld-server && sudo docker compose up -d"

# Wait a moment for server to start
sleep 5

# Check server status
print_status "Checking server status..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/palworld-server && sudo docker compose ps"

# Show server logs
print_status "Server logs (last 10 lines):"
ssh $SERVER_USER@$SERVER_IP "cd /opt/palworld-server && sudo docker compose logs --tail=10"

print_status "Configuration update complete!"
echo ""
echo "Server Details:"
echo "  Name: Blesse"
echo "  Password: shonda"
echo "  Type: Community Server (Public Lobby)"
echo "  IP: $SERVER_IP"
echo "  Port: 8211"
echo ""
print_warning "Players can now find your server in the community server list!"
