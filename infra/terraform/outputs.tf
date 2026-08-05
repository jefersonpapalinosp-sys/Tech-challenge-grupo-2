output "ec2_public_ip" {
  description = "IP público da instância EC2."
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "URL base da API ToggleMaster."
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "health_check" {
  description = "Endpoint de health check."
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/health"
}

output "rds_endpoint" {
  description = "Endpoint (host) do RDS PostgreSQL."
  value       = aws_db_instance.postgres.address
}

output "ssh_command" {
  description = "Comando SSH (requer key_name definido e a chave .pem local)."
  value       = var.key_name != "" ? "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.app.public_ip}" : "SSH por chave desabilitado (key_name vazio)"
}
