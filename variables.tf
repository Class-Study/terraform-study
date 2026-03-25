# ── Cloud ─────────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "Região AWS para deploy dos recursos"
  type        = string
  default     = "us-east-1"
}

# ── Projeto ───────────────────────────────────────────────────────────────────
variable "project_name" {
  description = "Nome do projeto (usado como prefixo nos recursos)"
  type        = string
  default     = "eduspace"
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ── Rede ──────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_frontend" {
  description = "CIDR da subnet do frontend"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_backend" {
  description = "CIDR da subnet do backend"
  type        = string
  default     = "10.0.2.0/24"
}

# ── EC2 ───────────────────────────────────────────────────────────────────────
variable "frontend_instance_type" {
  description = "Tipo da instância EC2 do frontend (Nginx + React)"
  type        = string
  default     = "t2.micro" # ~$8/mês — elegível ao Free Tier
}

variable "backend_instance_type" {
  description = "Tipo da instância EC2 do backend (Spring Boot + PostgreSQL + RabbitMQ)"
  type        = string
  default     = "t3.micro" # ~$15/mês — 2 vCPU / 2 GB RAM
}

variable "frontend_volume_size" {
  description = "Tamanho do volume raiz do frontend em GB"
  type        = number
  default     = 30
}

variable "backend_volume_size" {
  description = "Tamanho do volume raiz do backend em GB"
  type        = number
  default     = 30
}

# ── SSH ───────────────────────────────────────────────────────────────────────
variable "allowed_ssh_cidr" {
  description = "CIDR permitido para SSH no frontend. Use seu IP: curl ifconfig.me"
  type        = string
  default     = "0.0.0.0/0" # Restrinja ao seu IP em produção!
}

variable "ssh_public_key" {
  description = "Conteúdo da chave pública SSH para acesso às EC2 (conteúdo do arquivo .pub)"
  type        = string
}

# ── Aplicação ─────────────────────────────────────────────────────────────────
variable "front_version" {
  description = "Versão da imagem Docker do frontend"
  type        = string
  default     = "latest"
}

variable "back_version" {
  description = "Versão da imagem Docker do backend"
  type        = string
  default     = "latest"
}

# ── Banco de Dados ────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "eduspace"
}

variable "db_user" {
  description = "Usuário do banco de dados PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do banco de dados PostgreSQL"
  type        = string
  sensitive   = true
}

# ── RabbitMQ ──────────────────────────────────────────────────────────────────
variable "rabbitmq_user" {
  description = "Usuário do RabbitMQ"
  type        = string
  default     = "guest"
}

variable "rabbitmq_password" {
  description = "Senha do RabbitMQ"
  type        = string
  sensitive   = true
}

# ── JWT ───────────────────────────────────────────────────────────────────────
variable "jwt_secret" {
  description = "Secret JWT para o Spring Boot (mínimo 32 caracteres)"
  type        = string
  sensitive   = true
}
