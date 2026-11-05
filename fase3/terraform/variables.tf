variable "aws_region" {
  description = "Região da AWS. O AWS Academy só libera us-east-1 e us-west-2."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos nomes dos recursos e dos segredos."
  type        = string
  default     = "togglemaster"
}

# --- Rede ---

variable "vpc_cidr" {
  description = "Faixa de endereços da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas usadas pelas subnets. O EKS não aceita us-east-1e."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Subnets públicas, uma por zona. Recebem os nós do EKS e o Load Balancer."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Subnets privadas, uma por zona. Recebem os bancos e o cache."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# --- EKS ---

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "togglemaster"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes no EKS."
  type        = string
  default     = "1.37"
}

variable "eks_cluster_role_name" {
  description = "Role já existente usada pelo cluster. No AWS Academy é a LabRole, porque o laboratório não deixa criar roles."
  type        = string
  default     = "LabRole"
}

variable "eks_node_role_name" {
  description = "Role já existente usada pelos nós. No AWS Academy é a LabRole."
  type        = string
  default     = "LabRole"
}

variable "node_instance_types" {
  description = "Tipos de instância dos nós."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Quantidade inicial de nós."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade mínima de nós."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Quantidade máxima de nós."
  type        = number
  default     = 4
}

# --- Bancos e cache ---

variable "db_instance_class" {
  description = "Classe das instâncias RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL no RDS."
  type        = string
  default     = "18.3"
}

variable "redis_node_type" {
  description = "Tipo do nó do ElastiCache."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Versão do Redis no ElastiCache."
  type        = string
  default     = "7.1"
}

# --- Aplicação ---

variable "services" {
  description = "Serviços que ganham um repositório no ECR."
  type        = list(string)
  default = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
  ]
}

variable "analytics_table_name" {
  description = "Nome da tabela DynamoDB. O enunciado e o ConfigMap do analytics-service fixam este nome."
  type        = string
  default     = "ToggleMasterAnalytics"
}
