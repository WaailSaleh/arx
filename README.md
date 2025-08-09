# Palworld Server on Docker (Hetzner-ready)

This repository provides a ready-to-deploy stack for a Palworld dedicated server with an easy web management experience:

- Palworld server via `thijsvanloef/palworld-server-docker`
- Web RCON UI via `gorcon/rcon-web-admin`
- Live container logs via `Dozzle`
- Automatic image updates via `Watchtower`

## Quick start (local)

1. Copy `.env.example` to `.env` and fill secrets (`SERVER_PASSWORD`, `ADMIN_PASSWORD`, `RWA_PASSWORD`).
2. Start:
   
   ```bash
   docker compose up -d
   ```
3. Access:
   - **With SSL** (if domain configured): `https://yourdomain.com`, `https://files.yourdomain.com`, `https://logs.yourdomain.com`
   - **Without SSL**: `http://<host>:4326`, `http://<host>:8080`, `http://<host>:9999`
   - Admin Panel: Login with `ADMIN_PANEL_USER`/`ADMIN_PANEL_PASS`
   - File Manager: Login with `admin`/`admin`

## Deploy to Hetzner

You have two deployment options:

### Option 1: Local Deployment Script (Recommended)

1. **Configure deployment:**
   ```bash
   ./deploy.sh
   ```
   This creates `.env.deploy` - edit it with your server details:
   ```bash
   nano .env.deploy
   ```
   
   Required settings:
   - `HETZNER_HOST`: Your server IP
   - `HETZNER_USER`: SSH user (usually `root`)
   - `SSH_KEY_PATH`: Path to your SSH private key
   - `ADMIN_PASSWORD`: Strong password for RCON
   - `RWA_PASSWORD`: Password for web UI

2. **Deploy:**
   ```bash
   ./deploy.sh
   ```

The script will:
- Test SSH connection
- Install Docker if needed
- Sync files to server
- Generate `.env` and start containers
- Show access URLs

### Option 2: GitHub Actions

Set the following GitHub Secrets in your repository:

- Infrastructure
  - `HETZNER_HOST` (server IP or hostname)
  - `HETZNER_USER` (e.g. `root` or your user)
  - `HETZNER_DIR` (e.g. `/opt/palworld`)
  - `SSH_PRIVATE_KEY` (private key matching a public key in `~/.ssh/authorized_keys` on the server)

- Palworld config
  - `TZ`, `PUID`, `PGID` (optional)
  - `PORT`, `QUERY_PORT`, `PLAYERS` (optional)
  - `SERVER_NAME`, `SERVER_DESCRIPTION` (optional)
  - `ALLOW_CONNECT_PLATFORM` (default `Steam`)
  - `MULTITHREADING` (default `true`)
  - `COMMUNITY` (default `false`)
  - `RCON_ENABLED` (default `true`)
  - `RCON_PORT` (default `25575`)
  - `SERVER_PASSWORD` (required)
  - `ADMIN_PASSWORD` (required)

- Web UI
  - `RWA_HTTP_PORT` (default `4326`)
  - `RWA_USERNAME` (default `admin`)
  - `RWA_PASSWORD` (required)

- Logs UI
  - `DOZZLE_PORT` (default `9999`)

- Updates
  - `WATCHTOWER_SCHEDULE` (cron, default daily 04:00)

Push to `main` to deploy. The workflow will:

- Install Docker if missing
- Render `.env` on the server from secrets
- `docker compose up -d`

## Access & Management

After deployment:
- **Game Server**: `YOUR_SERVER_IP:8211` (password: `123` by default)
- **RCON Web UI**: `http://YOUR_SERVER_IP:4326` 
  - Login with your `RWA_USERNAME`/`RWA_PASSWORD`
  - Add server: host `palworld`, port `25575`, password = your `ADMIN_PASSWORD`
- **Live Logs**: `http://YOUR_SERVER_IP:9999`

## Server Requirements

- **CPU**: 4+ cores
- **RAM**: 16GB minimum (32GB recommended)
- **Storage**: 40GB+ SSD
- **Network**: Open ports UDP 8211, 27015 and TCP 4326, 9999

## Firewall Configuration

**Hetzner Cloud Firewall (Recommended):**
- UDP 8211 (game) - from anywhere
- UDP 27015 (query) - from anywhere  
- TCP 4326 (RCON web) - from your IP only
- TCP 9999 (logs) - from your IP only
- TCP 22 (SSH) - from your IP only

**Or via UFW on server:**
```bash
ufw allow ssh
ufw allow 8211/udp
ufw allow 27015/udp
ufw allow 4326/tcp
ufw allow 9999/tcp
ufw --force enable
```

## Security notes

- RCON web UI and Dozzle are exposed directly on their TCP ports. Use strong credentials and restrict access with your cloud firewall if possible.
- Expose only the ports you need. Consider a firewall (Hetzner Cloud firewall) allowing `UDP ${PORT}` and `UDP ${QUERY_PORT}`, plus `TCP` for web UIs you use.

## Management Commands

**Check status:**
```bash
ssh root@YOUR_SERVER_IP 'cd /opt/palworld && docker compose ps'
```

**View logs:**
```bash
ssh root@YOUR_SERVER_IP 'cd /opt/palworld && docker compose logs -f palworld-server'
```

**Restart server:**
```bash
ssh root@YOUR_SERVER_IP 'cd /opt/palworld && docker compose restart palworld-server'
```

**Update all containers:**
```bash
ssh root@YOUR_SERVER_IP 'cd /opt/palworld && docker compose pull && docker compose up -d'
```

## Data persistence

Game data lives in `./data/palworld` (mounted to `/palworld`). Back up this directory regularly.

## Troubleshooting

**Can't connect to game:**
- Check firewall allows UDP 8211
- Verify server logs show "ready for players"
- Try direct IP connection in Palworld

**Web UI not accessible:**
- Check firewall allows TCP 4326, 9999
- Verify containers are running: `docker compose ps`
- Check container logs: `docker compose logs rcon-web-admin`

**Server performance issues:**
- Monitor RAM usage (Palworld needs 16GB+)
- Check CPU usage during peak times
- Consider upgrading to larger Hetzner instance