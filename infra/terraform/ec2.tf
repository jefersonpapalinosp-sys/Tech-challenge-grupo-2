# AMI mais recente do Amazon Linux 2023 (x86_64).
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    repo_url    = var.repo_url
    app_port    = var.app_port
    db_host     = aws_db_instance.postgres.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
  })

  # Recria a instância se o script de bootstrap mudar.
  user_data_replace_on_change = true

  tags = {
    Name    = "${var.project_name}-app"
    Project = var.project_name
  }

  depends_on = [aws_db_instance.postgres]
}
