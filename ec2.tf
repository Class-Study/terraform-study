# ── AMI: Ubuntu (fornecida via variável) ──────────────────────────────────────
# ami-0ec10929233384c7f = Ubuntu 24.04 LTS us-east-1
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

# ── Backend EC2 ───────────────────────────────────────────────────────────────
# Criado PRIMEIRO porque o frontend precisa do private IP do backend
# Contém: Spring Boot + PostgreSQL 16 + RabbitMQ 3.13
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = aws_iam_instance_profile.backend_ec2.name

  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price                      = var.spot_max_price
        spot_instance_type             = "persistent"
        instance_interruption_behavior = "stop"
      }
    }
  }

  root_block_device {
    volume_size           = var.backend_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/backend_user_data.sh.tpl", {
    db_name           = var.db_name
    db_user           = var.db_user
    db_password       = var.db_password
    rabbitmq_user     = var.rabbitmq_user
    rabbitmq_password = var.rabbitmq_password
    jwt_secret        = var.jwt_secret
    back_version      = var.back_version
    aws_region        = var.aws_region
    project_name      = var.project_name
    environment       = var.environment
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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.frontend_instance_type
  subnet_id              = aws_subnet.frontend.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  key_name               = aws_key_pair.main.key_name

  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price                      = var.spot_max_price
        spot_instance_type             = "persistent"
        instance_interruption_behavior = "stop"
      }
    }
  }

  root_block_device {
    volume_size           = var.frontend_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data_replace_on_change = true
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
