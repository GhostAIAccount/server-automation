# server-automation

Home-server automation: a **Jellyfin** media server published securely through a **Cloudflare Tunnel**, a status **dashboard**, and **startup scripts** that bring the whole stack up automatically on boot.

> **No secrets in this repo.** Tokens, tunnel credentials, certs and `.env` files are git-ignored, auto-excluded on export, and checked by a secret scanner. See [Security](#security).

## Features

- 🎬 **Jellyfin media server**: containerised, config/cache/media on separate volumes
- ☁️ **Cloudflare Tunnel**: expose Jellyfin on your own domain with no open router ports and no public IP exposure; TLS and DDoS protection from Cloudflare
- 📊 **Dashboard**: at-a-glance status of services and the host
- 🚀 **Boot automation**: startup scripts / systemd units start Jellyfin, the tunnel and the dashboard in order after a reboot
- 🔐 **Secret hygiene**: `.env.example` template, strict `.gitignore`, redacting exporter, secret scanner and pre-commit hook

## Layout

```
server/
  jellyfin/     Jellyfin compose/config (no data, no DBs)
  cloudflare/   cloudflared config.yml (no credentials/cert)
  dashboard/    dashboard app/config
  startup/      boot scripts and systemd units
scripts/
  export-from-server.sh   copy + redact your live setup into this repo
  export.conf.example     list of paths to export
  scan-secrets.sh         fail if anything looks like a secret
  pre-commit              git hook that runs the scanner
.env.example              variables to set on the server
```

## Getting your live setup into the repo (run on the server)

```bash
git clone https://github.com/GhostAIAccount/server-automation.git && cd server-automation
cp scripts/export.conf.example scripts/export.conf   # edit paths (file is git-ignored)
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
./scripts/export-from-server.sh                      # copies, redacts, scans
git diff                                             # REVIEW everything yourself
git add -A && git commit -m "Add server setup" && git push origin main
```

The exporter never copies `.env`, `*.pem`, `*.key`, `cert.pem`, `credentials*.json`, `<UUID>.json` tunnel credentials, databases, logs or media. It replaces inline tokens/passwords with `REDACTED`, UUIDs with `<UUID>` and IP:port pairs with `<HOST>:PORT`, then runs the scanner, which aborts on any finding.

## Deploying from the repo

1. `cp .env.example .env` and fill in values (paths, `CLOUDFLARE_TUNNEL_TOKEN`).
2. Create the tunnel in Cloudflare Zero Trust and point a public hostname (e.g. `jellyfin.example.com`) at `http://jellyfin:8096`.
3. Install the startup unit(s) from `server/startup/` and enable them (`systemctl enable --now <unit>`).

## Security

- Secrets live only in `.env` on the server (git-ignored).
- Run `scripts/scan-secrets.sh` any time; the pre-commit hook runs it automatically.
- If a secret was ever committed or pasted anywhere, **rotate it** (regenerate the tunnel token in Cloudflare) and don't rely on deleting the commit.
