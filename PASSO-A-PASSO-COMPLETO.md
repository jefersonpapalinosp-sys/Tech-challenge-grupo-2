# Passo a Passo Completo — Reprodução Manual e Estudo

Documento de estudo que registra **tudo o que foi feito hoje**, na ordem, com o **porquê** de
cada passo, para você **reproduzir manualmente** depois e entender o processo de ponta a ponta.

> **Como usar:** leia da Parte 0 à 4 para reproduzir do zero. A Parte 4 é o **deploy manual na
> AWS** (o jeito "na mão", que é o objetivo de aprendizado da Fase 1). A Parte 5 mostra o
> atalho com Terraform. A Parte 6 explica como **pausar e retomar** entre sessões de estudo.

### Valores reais deste deploy (referência)
| Item | Valor |
| :--- | :---- |
| Região | **us-east-1** (o lab bloqueia us-east-2) |
| Conta / role | `537132640408` / `voclabs` |
| VPC | `vpc-090d321e9f286e710` (10.0.0.0/16) |
| EC2 | `i-000c923085ffa7de1` · IP `54.237.129.141` (muda ao religar) |
| RDS | `togglemaster-db.cpr3sig84ykp.us-east-1.rds.amazonaws.com:5432` |
| Repositório | https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2 |

---

## Parte 0 — Pré-requisitos e ferramentas

O que precisa estar instalado na sua máquina:
- **Git** e uma conta no **GitHub**.
- **Docker Desktop** (inclui `docker` e `docker compose`).
- **Terraform** (só se for usar o caminho automatizado da Parte 5).
- Acesso ao **AWS Academy Learner Lab**.
- Um cliente HTTP: `curl` (terminal), **Postman** ou **Insomnia**.

**Por quê:** Docker roda o app localmente igual em produção; Git/GitHub versiona e compartilha
o projeto com o grupo; o Learner Lab é onde a nuvem acontece.

---

## Parte 1 — Preparar o projeto e o Git

Foi o que estruturou o repositório do grupo a partir do código-base do desafio.

```bash
# 1. Criar a pasta do projeto e entrar nela
mkdir Tech-challenge-grupo-2 && cd Tech-challenge-grupo-2

# 2. Trazer o código do monólito (sem o histórico do repo original)
#    (hoje baixamos o .tar.gz do repositório-base e copiamos os arquivos)
#    app.py, Dockerfile, docker-compose.yaml, entrypoint.sh, requirements.txt, README.md

# 3. Iniciar o Git e apontar para o seu repositório vazio no GitHub
git init
git branch -M main
git remote add origin https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git

# 4. Criar o .gitignore (crucial: bloquear credenciais e state)
#    Ignora: .env, *.pem, *.tfstate, *.tfvars, venv/, __pycache__/, etc.

# 5. Primeiro commit e push
git add -A
git commit -m "estrutura inicial do projeto"
git push -u origin main
```

**Autenticação no push:** o GitHub não aceita senha no `git push`. Use o **GitHub CLI**
(`gh auth login`, fluxo *device code* no navegador) **ou** um **Personal Access Token**.
Foi assim que autenticamos hoje.

**Por quê o `.gitignore` primeiro:** o requisito de segurança nº 1 do desafio é **nunca**
subir credencial para o Git. O `.gitignore` garante isso mesmo se alguém rodar `git add -A`.

---

## Parte 2 — Entender a aplicação (o código)

| Arquivo | O que é | Ponto-chave para estudar |
| :------ | :------ | :----------------------- |
| `app.py` | API Flask com as rotas `/health` e `/flags` | Lê a conexão do banco de **variáveis de ambiente** (`DB_HOST`, etc.), nunca hardcoded |
| `requirements.txt` | Dependências Python | `Flask`, `gunicorn`, `psycopg2` (driver PostgreSQL) |
| `Dockerfile` | Como a imagem é construída | Parte de `python:3.9-slim`, instala deps, expõe 5000, roda via `entrypoint.sh` |
| `entrypoint.sh` | Script de partida do container | **Espera o banco** ficar pronto (`pg_isready`), cria a tabela (`flask init-db`) e sobe o Gunicorn |
| `docker-compose.yaml` | Orquestra local | Sobe 2 serviços: `app` e `db` (Postgres). O `db` tem *healthcheck* e o `app` só sobe depois |

**Conceito:** o app é um **monólito** — um único processo com toda a lógica. Vantagem: simples
de rodar e implantar. Desvantagem: escala tudo junto e é um ponto único de falha.

---

## Parte 3 — Rodar e testar localmente com Docker

```bash
# Na pasta do projeto
docker compose up --build       # sobe app + PostgreSQL
```

Em outro terminal, teste os 4 endpoints:
```bash
curl http://localhost:5000/health
# {"status":"ok"}

curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"new-feature","is_enabled":true}' http://localhost:5000/flags

curl http://localhost:5000/flags
curl http://localhost:5000/flags/new-feature

curl -X PUT -H "Content-Type: application/json" \
  -d '{"is_enabled":false}' http://localhost:5000/flags/new-feature
```

Encerrar:
```bash
docker compose down             # para os containers
# (docker compose down -v também apaga o volume/dados do Postgres)
```

> **Pegadinha do macOS:** a porta **5000** costuma estar ocupada pelo **Receptor AirPlay**.
> Desligue em *Ajustes do Sistema → Geral → AirDrop e Handoff → Receptor AirPlay*, ou mapeie
> outra porta (ex.: `5001:5000`). Foi o que aconteceu hoje.

**Por quê testar local antes:** você valida o app e entende o comportamento sem gastar/depender
da nuvem. Só depois vai para a AWS.

---

## Parte 4 — Deploy MANUAL na AWS (Console) — o passo a passo "na mão"

Este é o coração do aprendizado da Fase 1: provisionar cada peça manualmente e entender como
elas se conectam. (Também existe em [`DEPLOY.md`](DEPLOY.md).)

### 4.0 Entrar no lab e no console
1. AWS Academy → módulo **Learner Lab** → **Start Lab** → espere a bolinha **verde**.
2. Clique em **AWS** para abrir o console.
3. **Troque a região** (canto superior direito) para **N. Virginia — us-east-1**.
   > O lab **bloqueia us-east-2 (Ohio)** para EC2/VPC. Se ficar em Ohio, dá "acesso negado".

### 4.1 Criar a rede (VPC)
- Console → busque **VPC** → **Create VPC** → escolha **"VPC and more"**.
  - Name: `togglemaster-vpc` · CIDR `10.0.0.0/16`
  - AZs: **2** · Subnets públicas: **2** · privadas: 0 · NAT: **None**
- **Create VPC.** Isso cria automaticamente o **Internet Gateway** e a **route table** com a
  rota `0.0.0.0/0 → igw` (é o que torna a subnet "pública").

**Por quê:** a VPC é a sua rede isolada na AWS. O **RDS exige 2 AZs**, por isso 2 subnets.

> **Atalho de estudo:** dá para usar a **VPC default** do lab e pular esta etapa. Mas criar a
> sua é mais didático.

### 4.2 Criar os Security Groups (firewall)
Console → **EC2** → *Network & Security* → **Security Groups** → **Create**.

**`sg-togglemaster-web`** (para a EC2) — *Inbound rules*:
| Tipo | Porta | Origem |
| :--- | :---- | :----- |
| Custom TCP | 5000 | `0.0.0.0/0` (API pública) |
| SSH | 22 | **My IP** (só o seu IP) |

**`sg-togglemaster-db`** (para o RDS) — *Inbound rules*:
| Tipo | Porta | Origem |
| :--- | :---- | :----- |
| PostgreSQL | 5432 | **selecione o SG `sg-togglemaster-web`** (não um IP!) |

**Por quê (conceito mais importante da segurança):** a regra 5432 do banco aponta para o
**Security Group da EC2**, não para um IP. Assim **só a EC2** conecta no banco; ninguém de fora
da VPC alcança o RDS. É o **princípio do menor privilégio**.

### 4.3 Criar o banco RDS (PostgreSQL)
Console → **RDS** → **Create database** → **Standard create** → **PostgreSQL**.
- Template: **Free tier**
- DB identifier: `togglemaster-db` · Master username: `postgres` · defina uma **senha** (anote!)
- Instance: `db.t3.micro` · Storage: 20 GB
- **Connectivity:** VPC `togglemaster-vpc` · **Public access: No** · Security group:
  **`sg-togglemaster-db`**
- **Additional configuration → Initial database name:** `togglemaster` ← **essencial**
- **Create.** Espere ~5–10 min e **copie o Endpoint** (o `...rds.amazonaws.com`).

**Por quê RDS e não Postgres na EC2:** o RDS é **gerenciado** (backup, patch, possibilidade de
Multi-AZ). Você foca no app, não em administrar banco — cultura DevOps.

### 4.4 Criar a instância EC2 (o servidor)
Console → **EC2** → **Launch instance**.
- Name: `togglemaster-app`
- AMI: **Amazon Linux 2023** · Tipo: **t3.micro**
- **Key pair:** selecione **`vockey`** (a chave padrão do Learner Lab; baixe o `labsuser.pem`
  em *AWS Details* se for usar SSH)
- **Network:** VPC `togglemaster-vpc`, uma subnet **pública**, **Auto-assign public IP: Enable**
- **Firewall:** *Select existing* → **`sg-togglemaster-web`**
- **Launch.** Anote o **IP público**.

### 4.5 Instalar e rodar a aplicação na EC2
Conecte na instância — duas formas:
- **EC2 Instance Connect** (pelo navegador): EC2 → selecione a instância → **Connect** → aba
  *EC2 Instance Connect* → **Connect**.
- **SSH** (do seu Mac): `chmod 400 labsuser.pem && ssh -i labsuser.pem ec2-user@<IP>`

Depois, **escolha um** caminho:

**Opção A — Docker (recomendado):**
```bash
sudo dnf update -y
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER && newgrp docker

git clone https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git app && cd app
docker build -t togglemaster .

docker run -d --name togglemaster --restart always -p 5000:5000 \
  -e DB_HOST='<ENDPOINT-DO-RDS>' -e DB_PORT='5432' \
  -e DB_NAME='togglemaster' -e DB_USER='postgres' -e DB_PASSWORD='<SUA-SENHA>' \
  togglemaster
docker logs -f togglemaster    # deve mostrar "Banco disponível!" e o Gunicorn
```

**Opção B — Python + venv (como no README original):**
```bash
sudo dnf install -y git python3 python3-pip
git clone https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git app && cd app
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
export DB_HOST='<ENDPOINT-DO-RDS>' DB_NAME='togglemaster' DB_USER='postgres' DB_PASSWORD='<SENHA>'
flask init-db
gunicorn --bind 0.0.0.0:5000 app:app
```

**Diferença para estudar:** a **Opção A** (Docker `--restart always`) faz o app **voltar
sozinho** se a instância reiniciar. A **Opção B** roda no *foreground* e para quando você fecha
o SSH (em produção usaríamos `systemd`).

### 4.6 Testar (do seu computador)
```bash
IP=<IP-PUBLICO-EC2>
curl http://$IP:5000/health
curl -X POST -H "Content-Type: application/json" -d '{"name":"aws","is_enabled":true}' http://$IP:5000/flags
curl http://$IP:5000/flags
```
Se o `/health` responde mas `/flags` dá **erro 500**, é conexão com o RDS: confira o endpoint,
a senha, o *Initial database name = togglemaster* e a regra **5432** do SG do banco.

---

## Parte 5 — (Alternativa) Terraform — o que fizemos hoje

Em vez de clicar em tudo, provisionamos com **Infraestrutura como Código**. Resumo do que
rodamos (detalhes em [`infra/terraform/`](infra/terraform/)):

```bash
# credenciais do lab em ~/.aws/credentials (bloco de AWS Details > AWS CLI)
export TF_VAR_db_password="uma-senha-forte"
cd infra/terraform
terraform init          # baixa o provider AWS
terraform plan          # mostra o que será criado (12 recursos)
terraform apply         # cria tudo; a EC2 já sobe o app via user_data
terraform output        # IP, URL e endpoint do RDS
```

**O que o Terraform criou (12 recursos):** VPC, 2 subnets, Internet Gateway, route table +
2 associações, 2 Security Groups, DB Subnet Group, RDS e EC2.

**Vantagem para estudo:** compare — o que você fez em ~10 telas no console, o `apply` faz em
~6 minutos e de forma **repetível**. É a diferença entre "clicar" e "codar" a infra.

---

## Parte 6 — Pausar e retomar entre sessões de estudo (End Lab / Start Lab)

Você vai estudar em vários dias. Entenda o ciclo:

### Ao clicar em **End Lab** (hoje)
- A **EC2 é parada** (stopped) — o app sai do ar, mas o disco e o RDS/config **permanecem**.
- As **credenciais expiram**.
- **Nada é apagado** de imediato (mas o lab não garante para sempre).

### Ao **Start Lab** na próxima sessão
1. **Start Lab** → bolinha verde → abra o console → **região us-east-1**.
2. **EC2** → *Instances*: sua instância estará **Stopped**. Selecione → **Instance state → Start**.
   - Ao iniciar, o Docker sobe o container sozinho (`--restart always`).
   - ⚠️ **O IP público muda.** Pegue o novo em *Details* da instância.
3. **RDS** → se estiver *Stopped*, selecione → **Actions → Start**. Espere ficar *Available*.
4. Teste com o **IP novo**: `curl http://<NOVO-IP>:5000/health`.

> **Dica:** para não depender de o lab preservar tudo, lembre que você pode **recriar do zero**
> a qualquer momento (Parte 4 manual, ou Parte 5 com `terraform apply`).

### Se o lab tiver apagado os recursos
- Pelo Terraform: se o `terraform.tfstate` local apontar para coisas que não existem mais,
  apague-o (`rm terraform.tfstate*`) e rode `terraform apply` de novo.
- Manual: refaça a Parte 4.

---

## Parte 7 — Encerrar de vez (quando não precisar mais)

Para **zerar custos/consumo** quando terminar os estudos:
- **Terraform:** `cd infra/terraform && terraform destroy`.
- **Manual:** apague na ordem EC2 → RDS → VPC (a VPC leva junto subnets, IGW, route tables e SGs).
- Confira **Elastic IPs** ociosos e **snapshots** de RDS (cobram mesmo parados).

---

## Parte 8 — Conceitos-chave (glossário para estudar)

- **Monólito:** app único com toda a lógica. Simples de implantar; escala tudo junto.
- **VPC:** sua rede virtual isolada na AWS.
- **Subnet:** subdivisão da VPC dentro de uma AZ. "Pública" = tem rota para o Internet Gateway.
- **AZ (Availability Zone):** datacenter isolado dentro de uma região. RDS exige 2.
- **Internet Gateway (IGW):** porta de entrada/saída da VPC para a internet.
- **Route table:** regras de roteamento; a rota `0.0.0.0/0 → igw` deixa a subnet pública.
- **Security Group:** firewall *stateful* por recurso. Pode ter outro SG como "origem".
- **EC2:** máquina virtual. Aqui roda o container da aplicação (Gunicorn:5000).
- **RDS:** banco de dados **gerenciado**. Aqui, PostgreSQL, **não público**.
- **Gunicorn:** servidor WSGI de produção que serve o Flask.
- **IaC / Terraform:** descrever a infra em código para criar/destruir de forma repetível.
- **user_data:** script que a EC2 executa ao ligar (aqui: instala Docker e sobe o app).
- **Menor privilégio:** liberar só o necessário (ex.: banco só aceita a EC2, não a internet).

---

📌 **Documentos relacionados:** [`ARQUITETURA.md`](ARQUITETURA.md) (desenho e custos) ·
[`DEPLOY.md`](DEPLOY.md) (deploy manual) · [`GUIA-CONSULTA.md`](GUIA-CONSULTA.md) (como
consultar) · [`docs/ROTEIRO-VIDEO.md`](docs/ROTEIRO-VIDEO.md) (roteiro do vídeo).
