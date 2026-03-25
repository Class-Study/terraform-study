provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# ── Subnet: Frontend (public, internet-facing) ────────────────────────────────
resource "aws_subnet" "frontend" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_frontend
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-frontend"
    Tier = "public"
  }
}

# ── Subnet: Backend (public subnet, isolado via Security Group) ───────────────
# Sem NAT Gateway (~$32/mês) — o EC2 tem public IP só para baixar imagens Docker
# Todo acesso de entrada bloqueado pelo SG (apenas frontend SG pode acessar)
resource "aws_subnet" "backend" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_backend
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-backend"
    Tier = "backend"
  }
}

# ── Route Table ───────────────────────────────────────────────────────────────
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rt"
  }
}

resource "aws_route_table_association" "frontend" {
  subnet_id      = aws_subnet.frontend.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "backend" {
  subnet_id      = aws_subnet.backend.id
  route_table_id = aws_route_table.main.id
}

