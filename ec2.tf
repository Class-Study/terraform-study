# ── AMI: Amazon Linux 2023 (mais recente) ─────────────────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Backend EC2 ───────────────────────────────────────────────────────────────
# Criado PRIMEIRO porque o frontend precisa do private IP do backend
# Contém: Spring Boot + PostgreSQL 16 + RabbitMQ 3.13
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = aws_key_pair.main.key_name

  root_block_device {
    volume_size           = var.backend_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/templates/backend_user_data.sh.tpl", {
    db_name           = var.db_name
    db_user           = var.db_user
    db_password       = var.db_password
    rabbitmq_user     = var.rabbitmq_user
    rabbitmq_password = var.rabbitmq_password
    jwt_secret        = var.jwt_secret
    back_version      = var.back_version
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
    Role = "backend"
  }
}

# ── Frontend EC2 ──────────────────────────────────────────────────────────────
# Contém: Nginx (reverse proxy) + React/Vite frontend
# Recebe o private IP do backend para configurar o proxy Nginx
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.frontend_instance_type
  subnet_id              = aws_subnet.frontend.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  key_name               = aws_key_pair.main.key_name

  root_block_device {
    volume_size           = var.frontend_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/templates/frontend_user_data.sh.tpl", {
    backend_private_ip = aws_instance.backend.private_ip
    front_version      = var.front_version
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend"
    Role = "frontend"
  }

  depends_on = [aws_instance.backend]
}

