#!/bin/bash
# =============================================================================
# Backend EC2 - Setup Script (Ubuntu 24.04)
# Gerado pelo Terraform templatefile()
# Contém: PostgreSQL 16 + RabbitMQ 3.13 + Spring Boot (Java)
# Os valores sao variaveis Terraform - substituidas antes de rodar
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "========================================"
echo " Iniciando setup do Backend EC2"
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

# ── 3. Adicionar SWAP (2 GB) ──────────────────────────────────────────────────
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap de 2GB criado e ativado"
fi

# ── 4. Criar diretório da aplicação ──────────────────────────────────────────
mkdir -p /opt/app

# ── 5. Docker Compose ─────────────────────────────────────────────────────────
cat > /opt/app/docker-compose.yml << 'COMPOSE_EOF'
services:

  # ── PostgreSQL 16 ───────────────────────────────────────────────────────────
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB:       ${db_name}
      POSTGRES_USER:     ${db_user}
      POSTGRES_PASSWORD: ${db_password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${db_user} -d ${db_name}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # ── RabbitMQ 3.13 ───────────────────────────────────────────────────────────
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: ${rabbitmq_user}
      RABBITMQ_DEFAULT_PASS: ${rabbitmq_password}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: unless-stopped

  # ── Backend Spring Boot ─────────────────────────────────────────────────────
  backend:
    image: ghcr.io/class-study/study-back:${back_version}
    environment:
      SPRING_DATASOURCE_URL:      jdbc:postgresql://postgres:5432/${db_name}
      SPRING_DATASOURCE_USERNAME: ${db_user}
      SPRING_DATASOURCE_PASSWORD: ${db_password}
      SPRING_RABBITMQ_HOST:       rabbitmq
      SPRING_RABBITMQ_PORT:       "5672"
      SPRING_RABBITMQ_USERNAME:   ${rabbitmq_user}
      SPRING_RABBITMQ_PASSWORD:   ${rabbitmq_password}
      JWT_SECRET:                 ${jwt_secret}
      JAVA_OPTS:                  "-Xms256m -Xmx512m -Dspring.profiles.active=prod"
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/api/v1/actuator/health | grep -q UP || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: unless-stopped

volumes:
  postgres_data:
  rabbitmq_data:

COMPOSE_EOF

# ── 6. Permissões ─────────────────────────────────────────────────────────────
chown -R ubuntu:ubuntu /opt/app

echo "========================================"
echo " Backend setup concluido!"
echo " Spring Boot iniciando (aguarde ~60s)..."
echo " Logs: docker compose -f /opt/app/docker-compose.yml logs -f"
echo "========================================"
