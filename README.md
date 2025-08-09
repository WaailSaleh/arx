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
   - RCON UI: `http://<host>:4326`
   - Dozzle: `http://<host>:9999`

## Deploy via GitHub Actions to Hetzner

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

## Security notes

- RCON is NOT exposed to the internet; the web UI reaches it over the internal Docker network. Keep `ADMIN_PASSWORD` and `RWA_PASSWORD` strong.
- Expose only the ports you need. Consider a firewall (Hetzner Cloud firewall) allowing `UDP ${PORT}` and `UDP ${QUERY_PORT}`, plus `TCP` for the web UIs you use.

## Data persistence

Game data lives in `./data/palworld` (mounted to `/palworld`). Back up this directory regularly.