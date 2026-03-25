#!/bin/bash
# =============================================================================
# Frontend EC2 - Setup Script
# Gerado pelo Terraform templatefile()
# Contém: Nginx (reverse proxy) + React/Vite frontend
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "========================================"
echo " Iniciando setup do Frontend EC2"
echo " Backend IP: ${backend_private_ip}"
echo "========================================"

# ── 1. Instalar Docker ────────────────────────────────────────────────────────
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# ── 2. Instalar Docker Compose v2 (plugin) ────────────────────────────────────
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL \
  "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version

# ── 3. Criar estrutura de diretórios ─────────────────────────────────────────
mkdir -p /opt/app/nginx/conf.d /opt/app/nginx/certs

# ── 4. Nginx — configuração principal ────────────────────────────────────────
# Nota: heredoc QUOTED ('EOF') — bash NÃO expande variáveis
# Terraform já substituiu ${backend_private_ip} antes deste script executar
cat > /opt/app/nginx/nginx.conf << 'NGINX_MAIN_EOF'
user nginx;
worker_processes auto;

error_log /var/log/nginx/error.log warn;
pid       /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include      /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent"';

    access_log  /var/log/nginx/access.log main;
    sendfile    on;
    keepalive_timeout 65;
    client_max_body_size 20M;

    # Compressão gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    include /etc/nginx/conf.d/*.conf;
}
NGINX_MAIN_EOF

# ── 5. Nginx — site config (proxy frontend + API) ─────────────────────────────
# ATENÇÃO: ${backend_private_ip} é variável Terraform (substituída antes de rodar)
# Nginx usa $host, $remote_addr etc — ficam literais no quoted heredoc ✓
cat > /opt/app/nginx/conf.d/app.conf << 'NGINX_SITE_EOF'
upstream backend_api {
    server ${backend_private_ip}:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    # Healthcheck do próprio nginx
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # ── Proxy para API do backend ──────────────────────────────────────────
    location /api/ {
        proxy_pass         http://backend_api;
        proxy_http_version 1.1;
        proxy_set_header   Connection "";
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 90s;
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
    }

    # ── Serve o frontend React (SPA) ──────────────────────────────────────
    location / {
        proxy_pass         http://frontend:80;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host       $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_SITE_EOF

# ── 6. Docker Compose ─────────────────────────────────────────────────────────
# ${front_version} é variável Terraform — substituída antes de rodar ✓
cat > /opt/app/docker-compose.yml << 'COMPOSE_EOF'
services:

  # ── Nginx reverse-proxy ────────────────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - frontend
    restart: unless-stopped

  # ── Frontend React/Vite ────────────────────────────────────────────────────
  frontend:
    image: ghcr.io/class-study/study-front:${front_version}
    restart: unless-stopped

COMPOSE_EOF

# ── 7. Subir serviços ─────────────────────────────────────────────────────────
cd /opt/app
docker compose pull
docker compose up -d

echo "========================================"
echo " Frontend setup concluído!"
echo " Acesse: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "========================================"

