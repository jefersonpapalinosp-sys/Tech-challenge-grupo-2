variable "name" {
  description = "Prefixo dos nomes."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets privadas das instâncias."
  type        = list(string)
}

variable "client_security_group_id" {
  description = "Security group de onde as conexões são aceitas: o do cluster EKS."
  type        = string
}

variable "instance_class" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "databases" {
  description = "Uma instância por chave. O valor é o nome do banco criado nela."
  type        = map(string)
}

variable "master_username" {
  type    = string
  default = "togglemaster"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.name}-rds"
  description = "PostgreSQL do ToggleMaster, acessivel so a partir do EKS"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.client_security_group_id
  description                  = "PostgreSQL a partir dos nos do EKS"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Sem caracteres especiais, para a senha entrar na URL sem depender de escape.
resource "random_password" "master" {
  for_each = var.databases

  length  = 32
  special = false
}

resource "aws_db_instance" "this" {
  for_each = var.databases

  identifier     = "${var.name}-${each.key}"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = each.value
  username = var.master_username
  password = random_password.master[each.key].result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period  = 1
  delete_automated_backups = true
  skip_final_snapshot      = true
  deletion_protection      = false
  apply_immediately        = true
}

output "endpoints" {
  value = { for k, db in aws_db_instance.this : k => db.address }
}

# O RDS exige TLS por padrão, por isso o sslmode=require.
output "database_urls" {
  sensitive = true
  value = {
    for k, db in aws_db_instance.this :
    k => "postgres://${db.username}:${urlencode(random_password.master[k].result)}@${db.address}:${db.port}/${db.db_name}?sslmode=require"
  }
}
