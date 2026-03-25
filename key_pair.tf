# Chave pública registrada na AWS
# A chave é gerada uma vez localmente e armazenada no GitHub Secret: SSH_PUBLIC_KEY
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project_name}-${var.environment}-key"
  }
}
