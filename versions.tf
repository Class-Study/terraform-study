terraform {
  required_version = ">= 1.6.0"

  # ── State remoto no S3 ────────────────────────────────────────────────────
  backend "s3" {
    bucket  = "eduspace-terraform-state"
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
