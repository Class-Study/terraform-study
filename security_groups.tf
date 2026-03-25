# ── Frontend Security Group ───────────────────────────────────────────────────
# Internet → Frontend: 80 (HTTP), 443 (HTTPS), 22 (SSH)
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-${var.environment}-sg-frontend"
  description = "Frontend EC2: HTTP/HTTPS publico + SSH restrito"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH (restrinja ao seu IP em producao)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Todo outbound liberado"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-frontend"
  }
}

# ── Backend Security Group ────────────────────────────────────────────────────
# Regra: Nenhuma entrada da internet — APENAS do Frontend SG
# Isso substitui a VPC privada sem custo de NAT Gateway
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-${var.environment}-sg-backend"
  description = "Backend EC2: inbound apenas do Frontend SG (Spring Boot + DB + Rabbit)"
  vpc_id      = aws_vpc.main.id

  # Spring Boot API — somente o frontend pode chamar
  ingress {
    description     = "API Spring Boot via frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # SSH — frontend funciona como bastion host
  ingress {
    description     = "SSH via frontend bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # Outbound livre — necessário para baixar imagens Docker do ghcr.io
  egress {
    description = "Outbound para baixar imagens Docker e updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-backend"
  }
}

