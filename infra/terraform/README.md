# Infraestrutura como Código — Terraform (bônus)

Provisiona automaticamente toda a infraestrutura descrita em
[`../../ARQUITETURA.md`](../../ARQUITETURA.md): VPC dedicada, 2 subnets públicas, Internet
Gateway, Security Groups, RDS PostgreSQL e a EC2 já com a aplicação rodando (via `user_data`).

> Este é o caminho **automatizado** (diferencial). O caminho **manual** exigido pela Fase 1
> está em [`../../DEPLOY.md`](../../DEPLOY.md).

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.3
- Credenciais AWS configuradas (`aws configure`, variáveis `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`,
  ou o `aws_credentials` do **AWS Academy Learner Lab** em `~/.aws/credentials`).
- O repositório precisa ser **público** (a EC2 faz `git clone` dele para buildar a imagem).

## Arquivos

| Arquivo | Conteúdo |
| :------ | :------- |
| `versions.tf` | Provider AWS e versão do Terraform |
| `variables.tf` | Todas as variáveis parametrizáveis |
| `network.tf` | VPC, subnets, IGW, route tables |
| `security.tf` | Security Groups (web e db) |
| `rds.tf` | DB Subnet Group + instância RDS PostgreSQL |
| `ec2.tf` | AMI, instância EC2 e injeção do `user_data` |
| `user_data.sh.tftpl` | Bootstrap: instala Docker, clona o repo, sobe o container |
| `outputs.tf` | IP público, URL da app, endpoint do RDS, comando SSH |
| `terraform.tfvars.example` | Modelo de variáveis (copie para `terraform.tfvars`) |

## Uso

```bash
cd infra/terraform

# 1. Configure suas variáveis
cp terraform.tfvars.example terraform.tfvars   # edite key_name, allowed_ssh_cidr, etc.

# 2. A senha do banco por variável de ambiente (não versionada)
export TF_VAR_db_password="uma-senha-forte-aqui"

# 3. Fluxo padrão
terraform init
terraform plan      # revise o que será criado
terraform apply     # confirme com 'yes'
```

Ao final, o Terraform imprime os outputs. Teste:

```bash
curl "$(terraform output -raw health_check)"
# {"status":"ok"}
```

> A EC2 leva ~2–4 min após o `apply` para terminar o bootstrap (instalar Docker + build da
> imagem). Se o `curl` falhar logo de cara, aguarde e tente de novo, ou entre por SSH e rode
> `docker logs -f togglemaster`.

## Destruir (evita custos)

```bash
terraform destroy
```

## Notas de segurança

- `terraform.tfvars`, `*.tfstate` e `.terraform/` estão no `.gitignore` — **nunca** os
  versione (o state contém a senha do banco em texto).
- `allowed_ssh_cidr` deve ser o **seu IP/32**, não `0.0.0.0/0`.
- O RDS é criado com `publicly_accessible = false` e só aceita tráfego do SG da EC2.

## Compatibilidade com AWS Academy

- Não cria IAM roles/users (o Academy restringe isso) — a EC2 sobe sem instance profile.
- Usa apenas `t3.micro` / `db.t3.micro`, dentro do permitido no Learner Lab.
- Região padrão `us-east-1`. As credenciais do Learner Lab expiram a cada sessão; reexporte
  quando reabrir o lab.
