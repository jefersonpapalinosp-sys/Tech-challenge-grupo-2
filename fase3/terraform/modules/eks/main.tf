variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "cluster_role_arn" {
  description = "Role já existente do cluster."
  type        = string
}

variable "node_role_arn" {
  description = "Role já existente dos nós."
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnets onde o EKS cria as interfaces de rede do plano de controle."
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnets onde os nós são criados."
  type        = list(string)
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Quem roda o Terraform vira administrador do cluster. O CI nunca fala com o cluster.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  upgrade_policy {
    support_type = "STANDARD"
  }
}

# O hop limit 2 deixa os pods alcançarem as credenciais da role do nó. O External
# Secrets depende disso. Na Fase 2, nós recriados com hop limit 1 não funcionaram.
resource "aws_launch_template" "nodes" {
  name_prefix            = "${var.cluster_name}-nodes-"
  update_default_version = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.cluster_name}-node" }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.node_subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = var.node_instance_types

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  # A quantidade de nós pode mudar fora do Terraform, por escala manual ou automática.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

# Security group que o EKS cria e anexa ao plano de controle e aos nós.
# Os bancos e o cache liberam acesso só a partir dele.
output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  value = aws_eks_node_group.this.node_group_name
}
