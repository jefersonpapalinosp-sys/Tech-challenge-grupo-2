variable "namespace" {
  description = "Prefixo dos repositórios, como em togglemaster/auth-service."
  type        = string
}

variable "services" {
  type = list(string)
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.services)

  name = "${var.namespace}/${each.value}"

  # As tags são mutáveis para o pipeline poder ser executado de novo no mesmo commit.
  image_tag_mutability = "MUTABLE"

  # Deixa o terraform destroy apagar o repositório mesmo com imagens dentro.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter so as 10 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_urls" {
  value = { for k, repo in aws_ecr_repository.this : k => repo.repository_url }
}
