variable "prefix" {
  description = "Prefixo dos segredos, como em togglemaster/auth."
  type        = string
}

variable "database_urls" {
  description = "URL de conexão de cada banco, com as chaves auth, flag e targeting."
  type        = map(string)
  sensitive   = true
}

variable "redis_url" {
  type      = string
  sensitive = true
}

variable "sqs_queue_url" {
  type = string
}

# Chave mestra do auth-service, usada para criar chaves de API.
resource "random_password" "master_key" {
  length  = 40
  special = false
}

# Chave que o evaluation-service usa para chamar os outros serviços. O Job do
# auth-service grava o hash dela no banco, então o valor precisa ser o mesmo nos dois.
resource "random_id" "service_api_key" {
  byte_length = 24
}

locals {
  service_api_key = "tm_key_${random_id.service_api_key.hex}"

  # Este é o contrato com os ExternalSecrets de fase3/gitops.
  values = {
    auth = {
      DATABASE_URL    = var.database_urls["auth"]
      MASTER_KEY      = random_password.master_key.result
      SERVICE_API_KEY = local.service_api_key
    }
    flag = {
      DATABASE_URL = var.database_urls["flag"]
    }
    targeting = {
      DATABASE_URL = var.database_urls["targeting"]
    }
    evaluation = {
      REDIS_URL       = var.redis_url
      SERVICE_API_KEY = local.service_api_key
      AWS_SQS_URL     = var.sqs_queue_url
    }
    analytics = {
      AWS_SQS_URL = var.sqs_queue_url
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = toset(["auth", "flag", "targeting", "evaluation", "analytics"])

  name        = "${var.prefix}/${each.value}"
  description = "Configuracao sensivel do ${each.value}-service, lida pelo External Secrets"

  # Sem janela de recuperação, para o nome poder ser reutilizado logo depois de um destroy.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = aws_secretsmanager_secret.this

  secret_id     = each.value.id
  secret_string = jsonencode(local.values[each.key])
}

output "secret_names" {
  value = [for s in aws_secretsmanager_secret.this : s.name]
}
