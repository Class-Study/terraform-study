#!/bin/bash
# =============================================================================
# Frontend EC2 - Setup Script (Ubuntu 24.04)
# Gerado pelo Terraform templatefile()
# Contém: Nginx (reverse proxy) + React/Vite frontend
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "========================================"
echo " Iniciando setup do Frontend EC2"
echo " Backend IP: ${backend_private_ip}"
echo "========================================"

# ── 1. Atualizar sistema ──────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ── 2. Instalar Docker (método oficial Ubuntu) ────────────────────────────────
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker ubuntu

# ── 3. Criar estrutura de diretórios ─────────────────────────────────────────
mkdir -p /opt/app/nginx/conf.d /opt/app/nginx/certs

# ── 4. Nginx — configuração principal ────────────────────────────────────────
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

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    include /etc/nginx/conf.d/*.conf;
}
NGINX_MAIN_EOF

# ── 5. Nginx — site config (proxy frontend + API + WebSocket) ────────────────
cat > /opt/app/nginx/conf.d/app.conf << 'NGINX_SITE_EOF'
upstream backend_api {
    server ${backend_private_ip}:8080 max_fails=3 fail_timeout=10s;
    keepalive 32;
}

upstream frontend {
    server frontend:80;
}

server {
    listen 80;
    server_name _;

    # ── Let's Encrypt ACME challenge ─────────────────────────────────────────
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # ── Health check ──────────────────────────────────────────────────────────
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # ── Resposta graciosa quando o backend estiver offline ────────────────────
    error_page 502 503 504 = @backend_down;
    location @backend_down {
        default_type application/json;
        return 503 '{"error":"API temporarily unavailable","status":503}';
    }

    # ── WebSocket endpoint (deve vir antes do bloco /api/) ────────────────────
    # Nginx precisa encaminhar os headers Upgrade/Connection para que o backend
    # possa fazer o upgrade da conexão TCP para WebSocket.
    # Read timeout definido como 1 hora para manter conexões longas ativas.
    location /api/v1/ws {
        proxy_pass         http://backend_api;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host       $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    # ── REST API ──────────────────────────────────────────────────────────────
    location /api/ {
        proxy_pass         http://backend_api;
        proxy_http_version 1.1;
        proxy_set_header   Connection "";
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        client_max_body_size 50m;
        proxy_next_upstream error timeout http_502 http_503 http_504;
    }

    # ── Frontend SPA ──────────────────────────────────────────────────────────
    location / {
        proxy_pass         http://frontend;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        add_header X-Content-Type-Options  "nosniff"    always;
        add_header X-Frame-Options         "SAMEORIGIN" always;
        add_header Referrer-Policy         "strict-origin-when-cross-origin" always;
    }
}

# ── HTTPS server (descomentar quando o certificado TLS estiver disponível) ────
# server {
#     listen 443 ssl http2;
#     server_name yourdomain.com;
#
#     ssl_certificate     /etc/nginx/certs/fullchain.pem;
#     ssl_certificate_key /etc/nginx/certs/privkey.pem;
#
#     ssl_protocols             TLSv1.2 TLSv1.3;
#     ssl_ciphers               ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
#     ssl_prefer_server_ciphers off;
#     ssl_session_cache         shared:SSL:10m;
#     ssl_session_timeout       1d;
#     ssl_session_tickets       off;
#
#     # HSTS (habilitar após confirmar que HTTPS está funcionando corretamente)
#     # add_header Strict-Transport-Security "max-age=63072000" always;
#
#     location /api/v1/ws {
#         proxy_pass         http://backend_api;
#         proxy_http_version 1.1;
#         proxy_set_header   Upgrade    $http_upgrade;
#         proxy_set_header   Connection "upgrade";
#         proxy_set_header   Host       $host;
#         proxy_read_timeout 3600s;
#         proxy_send_timeout 3600s;
#     }
#
#     location /api/ {
#         proxy_pass         http://backend_api;
#         proxy_http_version 1.1;
#         proxy_set_header   Connection "";
#         proxy_set_header   Host              $host;
#         proxy_set_header   X-Real-IP         $remote_addr;
#         proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
#         proxy_set_header   X-Forwarded-Proto $scheme;
#         proxy_read_timeout 60s;
#         client_max_body_size 50m;
#     }
#
#     location / {
#         proxy_pass         http://frontend;
#         proxy_http_version 1.1;
#         proxy_set_header   Host              $host;
#         proxy_set_header   X-Real-IP         $remote_addr;
#         proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
#         proxy_set_header   X-Forwarded-Proto $scheme;
#     }
# }
NGINX_SITE_EOF

# ── 6. Docker Compose ─────────────────────────────────────────────────────────
cat > /opt/app/docker-compose.yml << 'COMPOSE_EOF'
services:

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

  frontend:
    image: ghcr.io/class-study/study-front:${front_version}
    restart: unless-stopped

COMPOSE_EOF

# ── 7. Permissões ─────────────────────────────────────────────────────────────
chown -R ubuntu:ubuntu /opt/app

echo "========================================"
echo " Frontend setup concluido!"
echo " Acesse: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "========================================"
