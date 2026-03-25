# 🚀 Eduspace — Infraestrutura AWS (Terraform)

Projeto Terraform para deploy de aplicação full-stack na AWS com **menor custo possível** para ambiente dev/test.

---

## 🏗️ Arquitetura

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16  (us-east-1)                         │
│                                                         │
│  ┌──────────────────────────┐                          │
│  │  Subnet Pública Frontend │  10.0.1.0/24 (us-east-1a) │
│  │                          │                          │
│  │  EC2 t3.micro            │                          │
│  │  ├── Nginx (80/443)      │◄── Internet              │
│  │  └── React/Vite          │                          │
│  └────────────┬─────────────┘                          │
│               │ SG: porta 8080 apenas                  │
│  ┌────────────▼─────────────┐                          │
│  │  Subnet Backend          │  10.0.2.0/24 (us-east-1b) │
│  │  (pública, isolada via SG)│                         │
│  │                          │                          │
│  │  EC2 t3.small            │                          │
│  │  ├── Spring Boot :8080   │                          │
│  │  ├── PostgreSQL :5432    │ ◄── Bloqueado pelo SG    │
│  │  └── RabbitMQ :5672      │     (sem acesso externo) │
│  └──────────────────────────┘                          │
└─────────────────────────────────────────────────────────┘
```

> **Por que sem NAT Gateway?** NAT Gateway custa ~$32/mês.
> Para dev/test, o backend EC2 tem um IP público **apenas para outbound** (baixar imagens Docker).
> O Security Group bloqueia TODO inbound externo — só o frontend SG pode acessar o backend.

---

## 💰 Estimativa de Custo Mensal (us-east-1)

| Recurso | Tipo | Custo |
|---|---|---|
| Frontend EC2 | t3.micro | ~$8.47 |
| Backend EC2 | t3.small | ~$16.94 |
| EBS Frontend | 8 GB gp3 | ~$0.64 |
| EBS Backend | 20 GB gp3 | ~$1.60 |
| NAT Gateway | **Não usado** | **$0.00** |
| **Total** | | **~$28/mês** |

---

## 📁 Estrutura de Arquivos

```
terraform-study/
├── versions.tf              # Versões dos providers (aws, tls, local)
├── main.tf                  # VPC, Subnets, IGW, Route Tables
├── variables.tf             # Todas as variáveis
├── security_groups.tf       # SGs (Frontend + Backend)
├── key_pair.tf              # Geração automática do par de chaves SSH
├── ec2.tf                   # Instâncias EC2 + AMI data source
├── outputs.tf               # IPs, URLs e comandos SSH
├── terraform.tfvars.example # Template de configuração
├── .gitignore               # Ignora state, .pem, tfvars
└── templates/
    ├── frontend_user_data.sh.tpl  # Setup: Nginx + React
    └── backend_user_data.sh.tpl   # Setup: Spring Boot + PG + Rabbit
```

---

## ⚡ Como usar

### 1. Pré-requisitos

- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://aws.amazon.com/cli/) configurado (`aws configure`)
- Credenciais AWS com permissões de EC2, VPC

### 2. Configurar variáveis

```bash
# Copie o exemplo e edite com suas configurações
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars`:
```hcl
db_password       = "SuaSenhaForte123!"
rabbitmq_password = "SuaSenhaRabbit456!"
jwt_secret        = "seu-segredo-jwt-com-minimo-32-chars!"
```

### 3. Deploy

```bash
# Inicializar providers
terraform init

# Visualizar o que será criado
terraform plan

# Criar infraestrutura
terraform apply
```

### 4. Acessar

Após o apply, os outputs mostram:

```bash
# URL da aplicação
application_url = "http://<IP>"

# SSH no frontend
ssh -i eduspace-dev.pem ec2-user@<FRONTEND_IP>

# SSH no backend (via frontend como bastion)
ssh -i eduspace-dev.pem -J ec2-user@<FRONTEND_IP> ec2-user@<BACKEND_PRIVATE_IP>
```

> ⏱️ Aguarde ~2-3 minutos após o apply para os containers subirem.

---

## 🔧 Verificar status dos serviços

**Frontend:**
```bash
ssh -i eduspace-dev.pem ec2-user@<FRONTEND_IP>
cd /opt/app
docker compose ps
docker compose logs -f
```

**Backend:**
```bash
# Conectar via bastion
ssh -i eduspace-dev.pem -J ec2-user@<FRONTEND_IP> ec2-user@<BACKEND_PRIVATE_IP>
cd /opt/app
docker compose ps
docker compose logs backend -f
```

---

## 🛑 Destruir ambiente

```bash
terraform destroy
```

---

## 🔒 Segurança (importante para produção)

- [ ] Restringir `allowed_ssh_cidr` ao seu IP: `curl ifconfig.me`
- [ ] Usar AWS Secrets Manager para senhas (em vez de tfvars)
- [ ] Adicionar HTTPS com certificado (Let's Encrypt / ACM)
- [ ] Adicionar domínio via Route 53
- [ ] Separar banco de dados para RDS (PostgreSQL gerenciado)
- [ ] Habilitar backup automático dos volumes EBS
- [ ] Configurar CloudWatch para monitoramento e alertas

---

## 📈 Próximos passos (escalabilidade)

- **Domínio próprio**: Route 53 + Certificate Manager (HTTPS gratuito)
- **Alta disponibilidade**: Auto Scaling Group + Application Load Balancer
- **Banco gerenciado**: Migrar PostgreSQL para RDS (backups automáticos)
- **Message broker gerenciado**: Migrar para Amazon MQ
- **CI/CD**: GitHub Actions com `terraform plan/apply`

