#!/usr/bin/env bash
# Despliega el backend de Jarvis en el VPS de Hostinger (sin EasyPanel).
#
# Uso (desde la carpeta raíz del proyecto, en Git Bash):
#   bash backend/deploy_vps.sh
#
# Necesita la llave SSH ~/.ssh/chattflow_vps (ya instalada en el VPS).
# Sube el código (sin node_modules, sin .env y sin data), reconstruye la imagen
# y reemplaza el contenedor. La base de datos (/opt/jarvis/data) y las claves
# (/opt/jarvis/.env) viven en el VPS y no se tocan.
# Queda publicado en https://jarvis.2-25-120-253.sslip.io/api
set -euo pipefail

VPS=root@2.25.120.253
KEY=~/.ssh/chattflow_vps
HOST=jarvis.2-25-120-253.sslip.io
cd "$(dirname "$0")/.."

tmp=$(mktemp)
tar czf "$tmp" --exclude=backend/node_modules --exclude=backend/.env --exclude=backend/data -C . backend
scp -i "$KEY" -q "$tmp" "$VPS:/opt/jarvis/jarvis-backend.tgz"
rm -f "$tmp"

ssh -i "$KEY" "$VPS" "HOST=$HOST bash -s" <<'REMOTE'
set -e
cd /opt/jarvis
rm -rf src && mkdir src && tar xzf jarvis-backend.tgz -C src --strip-components=1
docker build -q -t jarvis-backend:latest src >/dev/null
docker rm -f jarvis >/dev/null 2>&1 || true
docker run -d --name jarvis --restart unless-stopped --network web --memory 300m \
  --env-file /opt/jarvis/.env -v /opt/jarvis/data:/app/data \
  --label traefik.enable=true \
  --label "traefik.http.routers.jarvis.rule=Host(\`$HOST\`)" \
  --label traefik.http.routers.jarvis.entrypoints=websecure \
  --label traefik.http.routers.jarvis.tls.certresolver=letsencrypt \
  --label traefik.http.services.jarvis.loadbalancer.server.port=80 \
  jarvis-backend:latest >/dev/null
docker image prune -f >/dev/null
REMOTE

sleep 10
echo "Versión publicada: $(curl -s "https://$HOST/api/version")"
