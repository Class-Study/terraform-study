output "application_url" {
  description = "URL da aplicacao (frontend)"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "frontend_public_ip" {
  description = "IP publico do frontend EC2"
  value       = aws_instance.frontend.public_ip
}

output "frontend_public_dns" {
  description = "DNS publico do frontend EC2"
  value       = aws_instance.frontend.public_dns
}

output "backend_private_ip" {
  description = "IP privado do backend EC2 (acesso interno)"
  value       = aws_instance.backend.private_ip
}

output "backend_public_ip" {
  description = "IP publico do backend (apenas outbound - nao exponha em producao)"
  value       = aws_instance.backend.public_ip
}

output "ssh_frontend" {
  description = "Comando SSH para acessar o frontend"
  value       = "ssh -i ${var.project_name}-${var.environment}.pem ec2-user@${aws_instance.frontend.public_ip}"
}

output "ssh_backend" {
  description = "Comando SSH para acessar o backend (via frontend como bastion)"
  value       = "ssh -i ${var.project_name}-${var.environment}.pem -J ec2-user@${aws_instance.frontend.public_ip} ec2-user@${aws_instance.backend.private_ip}"
}

output "estimated_monthly_cost" {
  description = "Estimativa de custo mensal (us-east-1, On-Demand)"
  value = {
    frontend_ec2  = "t3.micro  → ~$8.47/mês"
    backend_ec2   = "t3.small  → ~$16.94/mês"
    ebs_frontend  = "8 GB gp3  → ~$0.64/mês"
    ebs_backend   = "20 GB gp3 → ~$1.60/mês"
    nat_gateway   = "NAT substituido por SG → $0.00/mês (economia de ~$32/mês)"
    total_approx  = "~$27-30/mês"
  }
}
