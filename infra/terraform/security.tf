# SG da aplicação (EC2): expõe a API e o SSH restrito.
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web"
  description = "Permite HTTP na porta da app e SSH restrito"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "API da aplicacao"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH restrito"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web"
    Project = var.project_name
  }
}

# SG do banco (RDS): só aceita 5432 vindo do SG da aplicação.
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db"
  description = "Permite PostgreSQL somente a partir do SG da aplicacao"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL a partir da EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-db"
    Project = var.project_name
  }
}
