#!/bin/bash
# =============================================================================
# Backend EC2 - Setup Script
# Gerado pelo Terraform templatefile()
# Contém: PostgreSQL 16 + RabbitMQ 3.13 + Spring Boot (Java)
# NOTA: Todos os valores sao variaveis Terraform - substituidas antes de rodar
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "========================================"
echo " Iniciando setup do Backend EC2"
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

# ── 3. Adicionar SWAP (2 GB) ──────────────────────────────────────────────────
# t3.small tem 2 GB RAM — Spring Boot + PG + Rabbit precisam de margem extra
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
# Os valores abaixo sao injetados pelo Terraform antes de rodar
# Quoted heredoc ('EOF') — bash não expande nada, valores já estão prontos
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

# ── Volumes persistentes ───────────────────────────────────────────────────────
volumes:
  postgres_data:
  rabbitmq_data:

COMPOSE_EOF

# ── 6. Subir serviços ─────────────────────────────────────────────────────────
cd /opt/app
docker compose pull
docker compose up -d

echo "========================================"
echo " Backend setup concluído!"
echo " Spring Boot iniciando (aguarde ~60s)..."
echo " Logs: docker compose -f /opt/app/docker-compose.yml logs -f"
echo "========================================"

