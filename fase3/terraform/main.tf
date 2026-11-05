data "aws_caller_identity" "current" {}

# No AWS Academy, o Terraform não pode criar roles. As duas são lidas pelo nome,
# o que atende à opção do enunciado de usar a LabRole por data source.
data "aws_iam_role" "eks_cluster" {
  name = var.eks_cluster_role_name
}

data "aws_iam_role" "eks_node" {
  name = var.eks_node_role_name
}

module "network" {
  source = "./modules/network"

  name                 = var.project
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks" {
  source = "./modules/eks"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  cluster_role_arn    = data.aws_iam_role.eks_cluster.arn
  node_role_arn       = data.aws_iam_role.eks_node.arn
  cluster_subnet_ids  = concat(module.network.public_subnet_ids, module.network.private_subnet_ids)
  node_subnet_ids     = module.network.public_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "rds" {
  source = "./modules/rds"

  name                     = var.project
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.private_subnet_ids
  client_security_group_id = module.eks.cluster_security_group_id
  instance_class           = var.db_instance_class
  engine_version           = var.db_engine_version

  # Uma instância por serviço, como pede o enunciado. O valor é o nome do banco.
  databases = {
    auth      = "auth_db"
    flag      = "flags_db"
    targeting = "targeting_db"
  }
}

module "elasticache" {
  source = "./modules/elasticache"

  name                     = var.project
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.private_subnet_ids
  client_security_group_id = module.eks.cluster_security_group_id
  node_type                = var.redis_node_type
  engine_version           = var.redis_engine_version
}

module "messaging" {
  source = "./modules/messaging"

  name                 = var.project
  analytics_table_name = var.analytics_table_name
}

module "ecr" {
  source = "./modules/ecr"

  namespace = var.project
  services  = var.services
}

module "secrets" {
  source = "./modules/secrets"

  prefix        = var.project
  database_urls = module.rds.database_urls
  redis_url     = module.elasticache.redis_url
  sqs_queue_url = module.messaging.sqs_queue_url
}
