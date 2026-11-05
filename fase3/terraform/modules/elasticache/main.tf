variable "name" {
  description = "Prefixo dos nomes."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets privadas do cache."
  type        = list(string)
}

variable "client_security_group_id" {
  description = "Security group de onde as conexões são aceitas: o do cluster EKS."
  type        = string
}

variable "node_type" {
  type = string
}

variable "engine_version" {
  type = string
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.name}-redis"
  description = "Redis do ToggleMaster, acessivel so a partir do EKS"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-redis" }
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.client_security_group_id
  description                  = "Redis a partir dos nos do EKS"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

resource "random_password" "auth_token" {
  length  = 32
  special = false
}

# Mesmo desenho da Fase 2: cluster mode ligado, 1 shard, TLS, AUTH e criptografia
# em repouso. O evaluation-service usa o cliente de cluster (REDIS_CLUSTER_MODE=true).
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Cache do evaluation-service"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = "default.redis7.cluster.on"

  num_node_groups            = 1
  replicas_per_node_group    = 0
  automatic_failover_enabled = true
  multi_az_enabled           = false

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.auth_token.result

  snapshot_retention_limit = 0
  apply_immediately        = true
}

output "configuration_endpoint" {
  value = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "redis_url" {
  sensitive = true
  value     = "rediss://:${random_password.auth_token.result}@${aws_elasticache_replication_group.this.configuration_endpoint_address}:6379"
}
