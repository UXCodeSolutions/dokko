#!/usr/bin/env bash
# FASE 27 — Despliegue del backend FastAPI en el VPS (Hostinger).
#
# Uso:
#   ./scripts/deploy.sh <usuario@vps-ip> [dominio]
#
# Requisitos en el VPS: Docker + docker compose ya instalados.
# Tras el primer despliegue, el dominio se expone via Caddy (auto-HTTPS).

set -euo pipefail

VPS="${1:?Uso: deploy.sh <usuario@vps-ip> [dominio]}"
DOMINIO="${2:-}"
PROYECTO="dokko"

echo "→ Subiendo código del backend al VPS..."
rsync -avz --delete --exclude venv --exclude __pycache__ --exclude ".env" \
  ./dokko-backend "$VPS":~/"$PROYECTO"/  2>/dev/null || {
  echo "rsync no disponible o falló; usando scp."
  scp -r dokko-backend "$VPS":~/"$PROYECTO"/
}

echo "→ Subiendo compose y .env encriptando el .env en el servidor..."
# .env viaja por ssh (tunel cifrado), nunca se deja en git.
scp ./dokko-compose.yml "$VPS":~/"$PROYECTO"/dokko-compose.yml
scp ./dokko-backend/.env "$VPS":~/"$PROYECTO"/dokko-backend/.env

echo "→ Build e inicio del contenedor en el VPS..."
ssh "$VPS" "cd ~/$PROYECTO && docker compose -f dokko-compose.yml up -d --build"

echo "→ Verificando healthcheck..."
ssh "$VPS" "sleep 5 && curl -fsS http://127.0.0.1:8000/health"

if [[ -n "$DOMINIO" ]]; then
  echo "→ Configurando Caddy para $DOMINIO (auto-HTTPS)..."
  ssh "$VPS" "cd ~/$PROYECTO && cat > Caddyfile <<'EOF'
$DOMINIO {
    reverse_proxy 127.0.0.1:8000
}
EOF
    docker run -d --name caddy -p 80:80 -p 443:443 \
      -v ~/$PROYECTO/Caddyfile:/etc/caddy/Caddyfile \
      -v caddy_data:/data -v caddy_config:/config \
      --restart unless-stopped caddy:2
    sleep 5 && curl -fsS https://$DOMINIO/health"
fi

echo "✅ Despliegue completado: http://127.0.0.1:8000 $([[ -n \"$DOMINIO\" ]] && echo \"| https://$DOMINIO\")"