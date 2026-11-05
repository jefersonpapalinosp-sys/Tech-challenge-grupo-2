terraform {
  # O bloqueio de estado com use_lockfile exige Terraform 1.11 ou mais novo.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # O nome do bucket vem de backend.hcl, porque muda de uma conta para outra:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "fase3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      Phase     = "fase3"
      ManagedBy = "terraform"
    }
  }
}
