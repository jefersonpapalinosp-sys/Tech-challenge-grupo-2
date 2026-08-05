# Guia de Deploy Manual na AWS — ToggleMaster

Passo-a-passo para provisionar a infraestrutura **manualmente pelo AWS Console** e implantar
a aplicação. Este é o caminho exigido pela Fase 1. Se preferir automatizar, veja
[`infra/terraform/`](infra/terraform/) (bônus).

> Região sugerida: **us-east-1** (N. Virginia). Use **AWS Academy Learner Lab** ou **Free Tier**.
> Tudo aqui cabe no Free Tier (t3.micro / db.t3.micro).

---

## Sumário
1. [Rede — VPC, Subnets, Internet Gateway](#1-rede)
2. [Security Groups](#2-security-groups)
3. [Banco de dados — RDS PostgreSQL](#3-rds-postgresql)
4. [Servidor — EC2](#4-ec2)
5. [Deploy da aplicação na EC2](#5-deploy-da-aplicacao)
6. [Testes](#6-testes)
7. [Limpeza (evitar custos)](#7-limpeza)

---

## 1. Rede

> **Atalho:** se estiver no AWS Academy e com pressa, você pode usar a **VPC default** (que
> já tem subnets públicas e IGW) e pular direto para a seção 2. O passo abaixo cria uma VPC
> dedicada, mais didático.

1. **VPC** → *Create VPC* → opção **"VPC and more"**.
   - Name tag: `togglemaster-vpc`
   - IPv4 CIDR: `10.0.0.0/16`
   - AZs: **2**
   - Subnets públicas: **2** · Subnets privadas: **2**
   - NAT gateways: **None** (economia) · VPC endpoints: **None**
   - *Create VPC*.
2. Isso já cria o **Internet Gateway** e as **route tables**. Confirme que as subnets
   públicas têm rota `0.0.0.0/0 → igw-...`.
3. Anote os IDs das 2 subnets públicas (usaremos uma para a EC2 e as duas para o RDS).

## 2. Security Groups

Crie **dois** Security Groups (EC2 → *Security Groups* → *Create*):

### `sg-togglemaster-web` (para a EC2)
| Tipo | Protocolo | Porta | Origem |
| :--- | :-------- | :---- | :----- |
| Custom TCP | TCP | 5000 | `0.0.0.0/0` (API pública) |
| SSH | TCP | 22 | **My IP** (seu IP `/32`) |

### `sg-togglemaster-db` (para o RDS)
| Tipo | Protocolo | Porta | Origem |
| :--- | :-------- | :---- | :----- |
| PostgreSQL | TCP | 5432 | **`sg-togglemaster-web`** (selecione o SG, não um IP) |

> 🔒 O ponto central: a regra 5432 do banco aponta para o **SG da EC2**, não para um IP.
> Só a EC2 fala com o RDS.

## 3. RDS PostgreSQL

1. **RDS** → *Create database* → **Standard create** → **PostgreSQL** (v13+).
2. **Templates:** *Free tier*.
3. **Settings:**
   - DB instance identifier: `togglemaster-db`
   - Master username: `postgres` (ou `dbadmin`)
   - Master password: defina uma senha forte (guarde-a — vai no `.env`/variáveis).
4. **Instance:** `db.t3.micro`. **Storage:** 20 GB gp2/gp3 (desmarque autoscaling).
5. **Connectivity:**
   - VPC: `togglemaster-vpc`
   - DB Subnet Group: deixe criar (usa as subnets da VPC — precisa de 2 AZs).
   - **Public access: No**
   - VPC security group: **existente** → `sg-togglemaster-db` (remova o default).
6. **Additional configuration:**
   - Initial database name: `togglemaster` ← **importante**, senão a app não acha o banco.
7. *Create database*. Espere ~5–10 min e **anote o Endpoint** (algo como
   `togglemaster-db.xxxx.us-east-1.rds.amazonaws.com`).

## 4. EC2

1. **EC2** → *Launch instance*.
   - Name: `togglemaster-app`
   - AMI: **Amazon Linux 2023** (ou Ubuntu 22.04)
   - Type: **t3.micro** (ou t2.micro)
   - **Key pair:** crie/selecione um par de chaves `.pem` (guarde para o SSH).
   - **Network:** VPC `togglemaster-vpc`, uma **subnet pública**, **Auto-assign public IP: Enable**.
   - **Firewall:** *Select existing security group* → `sg-togglemaster-web`.
2. *Launch instance*. Anote o **IP público**.

## 5. Deploy da aplicação

Conecte via SSH (ajuste o caminho da chave e o IP):

```bash
chmod 400 sua-chave.pem
ssh -i sua-chave.pem ec2-user@<IP-PUBLICO-EC2>   # Ubuntu: ubuntu@<IP>
```

Há dois caminhos. **Escolha um.**

### Opção A — Rodar via Docker (recomendado, reaproveita o Dockerfile)

```bash
# Amazon Linux 2023
sudo dnf update -y
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER && newgrp docker

git clone https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git app
cd app

docker build -t togglemaster .

docker run -d --name togglemaster --restart always -p 5000:5000 \
  -e DB_HOST='<ENDPOINT-DO-RDS>' \
  -e DB_PORT='5432' \
  -e DB_NAME='togglemaster' \
  -e DB_USER='postgres' \
  -e DB_PASSWORD='<SUA-SENHA-RDS>' \
  togglemaster

docker logs -f togglemaster   # deve mostrar "Banco de dados disponível!" e o Gunicorn subindo
```

O `entrypoint.sh` aguarda o banco, roda `flask init-db` (cria a tabela `flags`) e sobe o Gunicorn.

### Opção B — Rodar com Python + venv (como no README original)

```bash
# Amazon Linux 2023
sudo dnf update -y
sudo dnf install -y git python3 python3-pip postgresql15

git clone https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git app
cd app
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

export DB_HOST='<ENDPOINT-DO-RDS>'
export DB_NAME='togglemaster'
export DB_USER='postgres'
export DB_PASSWORD='<SUA-SENHA-RDS>'

flask init-db                       # cria a tabela
gunicorn --bind 0.0.0.0:5000 app:app
```

> ⚠️ **Nunca** faça commit das credenciais. No modo Python elas vivem só na sessão do shell;
> no modo Docker, passe-as via `-e` (ou um arquivo `.env` **não versionado** + `--env-file`).
> Rodar no *foreground* (Opção B) cai ao fechar o SSH — para persistir, use Docker
> `--restart always` (Opção A) ou um serviço `systemd`.

## 6. Testes

Do seu computador, apontando para o IP público da EC2:

```bash
IP=<IP-PUBLICO-EC2>

curl http://$IP:5000/health
# {"status":"ok"}

curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"new-feature","is_enabled":true}' http://$IP:5000/flags

curl http://$IP:5000/flags
curl http://$IP:5000/flags/new-feature

curl -X PUT -H "Content-Type: application/json" \
  -d '{"is_enabled":false}' http://$IP:5000/flags/new-feature
```

Se o `/health` responde mas os `/flags` dão erro 500, quase sempre é **conexão com o RDS**:
confira o endpoint, a senha, o `initial database name = togglemaster` e a regra 5432 do
`sg-togglemaster-db` apontando para o `sg-togglemaster-web`.

## 7. Limpeza

Para **evitar cobranças** após a avaliação, remova na ordem:

1. **EC2** → *Terminate instance*.
2. **RDS** → *Delete* (pode desmarcar o snapshot final para não guardar backup).
3. **VPC** → deletar a VPC criada (remove subnets, IGW, route tables e SGs juntos).
4. Confira **Elastic IPs** ociosos e **snapshots** — são cobrados mesmo parados.

> Alternativa automática: se usou o Terraform do repo, basta `terraform destroy`.
