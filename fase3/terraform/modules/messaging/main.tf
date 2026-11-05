variable "name" {
  description = "Prefixo dos nomes."
  type        = string
}

variable "analytics_table_name" {
  type = string
}

# Fila que recebe um evento a cada avaliação de flag.
resource "aws_sqs_queue" "events" {
  name                       = "${var.name}-events"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true
}

# Tabela onde o analytics-service grava os eventos lidos da fila.
resource "aws_dynamodb_table" "analytics" {
  name         = var.analytics_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
}

output "sqs_queue_url" {
  value = aws_sqs_queue.events.url
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.analytics.name
}
