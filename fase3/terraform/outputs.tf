output "aws_region" {
  description = "Valor da variável AWS_REGION no GitHub."
  value       = var.aws_region
}

output "ecr_registry" {
  description = "Valor da variável ECR_REGISTRY no GitHub."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repositories" {
  description = "Repositórios criados no ECR."
  value       = module.ecr.repository_urls
}

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Comando que configura o kubectl para o cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "VPC criada."
  value       = module.network.vpc_id
}

output "database_endpoints" {
  description = "Endereço de cada instância RDS."
  value       = module.rds.endpoints
}

output "redis_endpoint" {
  description = "Endpoint de configuração do cluster Redis."
  value       = module.elasticache.configuration_endpoint
}

output "sqs_queue_url" {
  description = "URL da fila de eventos."
  value       = module.messaging.sqs_queue_url
}

output "dynamodb_table" {
  description = "Tabela de eventos do analytics-service."
  value       = module.messaging.dynamodb_table_name
}

output "secret_names" {
  description = "Segredos criados no Secrets Manager, lidos pelo External Secrets."
  value       = module.secrets.secret_names
}
