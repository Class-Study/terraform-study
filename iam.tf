# ── IAM Role para EC2 Backend escrever no CloudWatch ─────────────────────────
resource "aws_iam_role" "backend_ec2" {
  name = "${var.project_name}-${var.environment}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-role"
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-${var.environment}-cloudwatch-logs"
  role = aws_iam_role.backend_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_iam_instance_profile" "backend_ec2" {
  name = "${var.project_name}-${var.environment}-backend-profile"
  role = aws_iam_role.backend_ec2.name
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/${var.project_name}/${var.environment}/backend"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/${var.project_name}/${var.environment}/postgres"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres-logs"
  }
}

resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/${var.project_name}/${var.environment}/rabbitmq"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-rabbitmq-logs"
  }
}

