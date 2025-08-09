# Palworld Dedicated Server + Save Uploader

Fast, Docker-based Palworld server with a web uploader to import an existing world.

## Quick start (Ubuntu)

1. Install Docker and bring the stack up:
   ```bash
   git clone . /opt/palworld-server # or copy this repo to the server
   cd /opt/palworld-server
   bash scripts/deploy.sh
   ```

2. Open firewall (if using UFW):
   ```bash
   sudo ufw allow 8211/udp
   sudo ufw allow 27015/udp
   sudo ufw allow 25575/tcp  # optional RCON
   sudo ufw allow 8080/tcp   # uploader web UI
   ```

3. Connect to the game:
   - Server name: configured in `docker-compose.yml` (default: `Blesse`)
   - Direct connect: `<server-ip>:8211`

## Upload an existing save

- Open the uploader: `http://<server-ip>:8080/`
- Choose your zipped world (contains `Level.sav` and `WorldOption.sav`), submit.
- The uploader extracts to the server path:
  - `/palworld/Pal/Saved/SaveGames/0` (inside the container)
- It will restart the Palworld container automatically.

You can also copy manually via SFTP/SSH while the server is stopped:
- Host path: the named volume `palworld_data` is mounted at `/var/lib/docker/volumes/palworld_data/_data` (on the host)
- In there: `Pal/Saved/SaveGames/0/<YourWorldFolder>`

## Configuration

Edit `docker-compose.yml` to change:
- `SERVER_NAME`, `SERVER_PASSWORD`, `ADMIN_PASSWORD`, `COMMUNITY`, `PLAYERS`, etc.
- Ports if needed.

Apply changes:
```bash
docker compose up -d
```

## Backups

The server data is in the Docker named volume `palworld_data`. Create a tarball backup:
```bash
sudo tar -C /var/lib/docker/volumes/palworld_data/_data -czf palworld_backup_$(date +%F).tgz .
```

## Troubleshooting

- Check logs:
  ```bash
  docker compose logs -f palworld
  docker compose logs -f palworld-uploader
  ```
- Ensure UDP ports 8211 and 27015 are open.
- If the uploader cannot restart the server, verify the Docker socket mapping and that the service name is `palworld`.