variable "region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado nas tags e nomes dos recursos."
  type        = string
  default     = "togglemaster"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das duas subnets públicas (uma por AZ). O RDS exige 2 AZs."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "Tipo da instância EC2 (Free Tier: t3.micro/t2.micro)."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nome de um Key Pair EXISTENTE na AWS para acesso SSH. Deixe vazio para não habilitar SSH por chave."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR autorizado a acessar a porta 22 (SSH). Use SEU-IP/32. 0.0.0.0/0 é inseguro."
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_port" {
  description = "Porta em que a aplicação escuta."
  type        = number
  default     = 5000
}

variable "repo_url" {
  description = "URL pública do repositório Git a ser clonado na EC2 (para build da imagem)."
  type        = string
  default     = "https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git"
}

# ---- Banco de dados (RDS) ----

variable "db_instance_class" {
  description = "Classe da instância RDS (Free Tier: db.t3.micro)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento do RDS em GB (Free Tier até 20)."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL."
  type        = string
  default     = "13"
}

variable "db_name" {
  description = "Nome do banco de dados inicial criado no RDS."
  type        = string
  default     = "togglemaster"
}

variable "db_username" {
  description = "Usuário master do RDS."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do usuário master do RDS. NÃO versione — passe via -var ou TF_VAR_db_password."
  type        = string
  sensitive   = true
}
