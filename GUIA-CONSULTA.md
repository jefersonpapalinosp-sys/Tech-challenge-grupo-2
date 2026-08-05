# Guia de Consulta e Processo — ToggleMaster (Tech Challenge Fase 1)

Este documento explica **tudo o que foi feito**, **como consultar a aplicação** (no seu
navegador e no terminal) e **como navegar no console da AWS Academy** para ver cada recurso —
com o caminho de cliques e uma explicação do processo do começo ao fim.

> **Dados reais deste deploy** (guarde para consulta rápida):
>
> | Item | Valor |
> | :--- | :---- |
> | Região AWS | **us-east-1** (N. Virginia) — *o lab bloqueia us-east-2* |
> | URL da aplicação | http://54.237.129.141:5000 |
> | IP público da EC2 | `54.237.129.141` (instância `i-000c923085ffa7de1`) |
> | Endpoint do RDS | `togglemaster-db.cpr3sig84ykp.us-east-1.rds.amazonaws.com` |
> | VPC | `vpc-090d321e9f286e710` (10.0.0.0/16) |
> | Conta / role | `537132640408` / `voclabs` |
>
> ⚠️ O **IP público muda** toda vez que a EC2 é parada e religada. Se mudar, rode
> `cd infra/terraform && terraform output` para ver o novo, ou pegue no console (Parte 3.1).

---

# Parte 1 — O que foi feito (item a item)

### 1.1 Código da aplicação (o monólito)
API REST em **Flask** servida por **Gunicorn**, com persistência em **PostgreSQL**. Gerencia
*feature flags* (ligar/desligar funcionalidades). Arquivos principais:
- [`app.py`](app.py) — a API e os endpoints (`/health`, `/flags`).
- [`Dockerfile`](Dockerfile) — como a imagem da aplicação é construída.
- [`docker-compose.yaml`](docker-compose.yaml) — sobe app + PostgreSQL para uso local.
- [`entrypoint.sh`](entrypoint.sh) — espera o banco, cria a tabela (`flask init-db`) e sobe o Gunicorn.
- [`requirements.txt`](requirements.txt) — dependências Python.

### 1.2 Ambiente local com Docker
Configurado para subir **aplicação + banco** com um comando (`docker compose up`). Serve para
desenvolver e testar antes da nuvem. Foi testado e todos os endpoints funcionaram.

### 1.3 Documentação
- [`ARQUITETURA.md`](ARQUITETURA.md) — desenho na AWS, decisões, **estimativa de custos** e o diagrama.
- [`DEPLOY.md`](DEPLOY.md) — passo-a-passo do deploy **manual** no console (o que a Fase 1 pede).
- [`docs/diagrama-arquitetura.png`](docs/diagrama-arquitetura.png) — diagrama renderizado (PNG).
- [`docs/arquitetura.drawio`](docs/arquitetura.drawio) — diagrama **editável** (abre no draw.io).
- [`docs/ROTEIRO-VIDEO.md`](docs/ROTEIRO-VIDEO.md) — roteiro cronometrado do vídeo (15 min).
- [`docs/evidencias/`](docs/evidencias/) — prints da aplicação rodando na AWS.
- [`ENTREGA.md`](ENTREGA.md) — relatório de entrega (nomes, links, decisões).

### 1.4 Infraestrutura como Código (Terraform) — *bônus*
Em [`infra/terraform/`](infra/terraform/), provisiona **toda** a infra automaticamente. O que
cada arquivo faz:
- `versions.tf` — provider AWS e versão do Terraform.
- `variables.tf` — variáveis parametrizáveis (região, tipos, senha do banco, etc.).
- `network.tf` — **VPC**, 2 **subnets** públicas, **Internet Gateway** e **route table**.
- `security.tf` — os 2 **Security Groups** (web e banco).
- `rds.tf` — **DB Subnet Group** + instância **RDS PostgreSQL**.
- `ec2.tf` — busca a AMI e cria a **EC2**, injetando o script de bootstrap.
- `user_data.sh.tftpl` — script que roda na EC2 ao ligar: instala Docker, clona o repo,
  builda a imagem e sobe o container apontando para o RDS.
- `outputs.tf` — imprime IP, URL, endpoint do RDS e comando SSH ao final.

### 1.5 Provisionamento na AWS (o que subiu)
Com `terraform apply`, foram criados **12 recursos** de uma vez, na região us-east-1:
VPC, 2 subnets (us-east-1a e us-east-1b), Internet Gateway, route table + 2 associações,
2 Security Groups, DB Subnet Group, RDS PostgreSQL e a EC2.

### 1.6 Deploy da aplicação
A EC2 subiu já rodando a aplicação (via `user_data`): Docker → build da imagem → container
Gunicorn na porta 5000 → conectado ao RDS. Sem passos manuais na instância.

### 1.7 Validação
Todos os endpoints foram exercitados contra o IP público e responderam corretamente,
incluindo a **gravação/leitura no RDS** e os casos de erro (409 duplicado, 404 inexistente).
Prints em [`docs/evidencias/`](docs/evidencias/).

### 1.8 Publicação no GitHub
Tudo versionado em https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2 —
**sem credenciais** no repositório (protegidas pelo `.gitignore`).

---

# Parte 2 — Como consultar a aplicação ("aqui")

A API tem 4 rotas:

| Método | Rota | O que faz | Dá para ver no navegador? |
| :----- | :--- | :-------- | :------------------------ |
| GET | `/health` | Diz se a app está no ar | ✅ Sim |
| GET | `/flags` | Lista todas as flags (lê do RDS) | ✅ Sim |
| GET | `/flags/<nome>` | Mostra uma flag específica | ✅ Sim |
| POST | `/flags` | Cria uma flag | ❌ Não (precisa curl/Postman) |
| PUT | `/flags/<nome>` | Liga/desliga uma flag | ❌ Não (precisa curl/Postman) |

### 2.1 No navegador (o mais simples)
Abra estes links (é a EC2 pública na AWS):
- Saúde: http://54.237.129.141:5000/health
- Lista de flags: http://54.237.129.141:5000/flags
- Uma flag: http://54.237.129.141:5000/flags/video-demo

> O navegador só faz **GET**. Para criar/atualizar flags (POST/PUT), use o terminal ou o Postman.

### 2.2 Pelo terminal (curl) — todos os métodos
```bash
IP=54.237.129.141

# Saúde
curl http://$IP:5000/health

# Criar uma flag
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"minha-flag","is_enabled":true}' http://$IP:5000/flags

# Listar
curl http://$IP:5000/flags

# Consultar uma
curl http://$IP:5000/flags/minha-flag

# Atualizar (desligar)
curl -X PUT -H "Content-Type: application/json" \
  -d '{"is_enabled":false}' http://$IP:5000/flags/minha-flag
```

### 2.3 Localmente com Docker (sem AWS)
No seu Mac, dentro da pasta do projeto:
```bash
docker compose up --build      # sobe app + PostgreSQL
curl http://localhost:5000/health
docker compose down            # encerra
```
> No macOS, a porta 5000 costuma estar ocupada pelo **Receptor AirPlay**. Desligue em
> *Ajustes do Sistema → Geral → AirDrop e Handoff → Receptor AirPlay*, ou use outra porta.

---

# Parte 3 — Como consultar na AWS Academy (caminho no console)

### 3.0 Entrar no lab e abrir o console (IMPORTANTE: região us-east-1)
1. No **AWS Academy** (Canvas), abra o módulo do **Learner Lab**.
2. Clique em **Start Lab** e espere a bolinha ao lado de **AWS** ficar **verde**.
3. Clique em **AWS** (ao lado da bolinha) para abrir o **console**.
4. **Troque a região** no canto **superior direito** para **N. Virginia (us-east-1)**.
   > Se ficar em *Ohio (us-east-2)* você **não verá** os recursos — eles estão em us-east-1.

### 3.1 Ver a instância EC2 (a aplicação)
- **Caminho:** barra de busca (topo) → digite **EC2** → *Instances (Instâncias)*.
- Procure a instância **`togglemaster-app`**.
- Clique nela para ver: **Public IPv4 address** (o IP da app), estado *Running*, tipo `t3.micro`.
- **O que provar no vídeo:** o IP público bate com o da URL da aplicação.

### 3.2 Ver o banco de dados RDS
- **Caminho:** busca → **RDS** → *Databases (Bancos de dados)*.
- Abra **`togglemaster-db`**.
- Verifique: **Status = Available**, **Publicly accessible = No**, engine *PostgreSQL*,
  e o **Endpoint** (`togglemaster-db.cpr3sig84ykp.us-east-1.rds.amazonaws.com`).
- **O que provar:** o banco é gerenciado (RDS) e **não é público** — só a EC2 acessa.

### 3.3 Ver a rede (VPC, subnets, gateway)
- **Caminho:** busca → **VPC**.
- Em *Your VPCs*: **`togglemaster-vpc`** (CIDR 10.0.0.0/16).
- Em *Subnets*: **`togglemaster-public-1`** (us-east-1a) e **`togglemaster-public-2`** (us-east-1b).
- Em *Internet gateways*: **`togglemaster-igw`** (dá acesso à internet).
- Em *Route tables*: **`togglemaster-public-rt`** tem a rota `0.0.0.0/0 → igw` (torna as subnets públicas).

### 3.4 Ver os Security Groups (o coração da segurança) 🔒
- **Caminho:** **EC2** → menu lateral esquerdo → *Network & Security* → **Security Groups**.
- **`togglemaster-web`** (da EC2) → aba *Inbound rules*:
  - `5000` TCP de `0.0.0.0/0` (API pública)
  - `22` TCP (SSH)
- **`togglemaster-db`** (do RDS) → aba *Inbound rules*:
  - `5432` TCP cuja **origem (Source) é o Security Group `togglemaster-web`** — **não** um IP.
- **O que provar no vídeo:** o banco só aceita conexão **vinda da EC2**. Esse é o ponto de
  segurança (menor privilégio) que a Fase 1 pede para demonstrar.

### 3.5 (Opcional) Ver os logs da aplicação na EC2
Duas formas:
- **EC2 Instance Connect (pelo navegador):** EC2 → selecione a instância → **Connect** →
  aba *EC2 Instance Connect* → **Connect**. Abre um terminal no navegador. Rode:
  ```bash
  sudo docker ps               # mostra o container togglemaster rodando
  sudo docker logs togglemaster   # mostra "Banco disponível!" e o Gunicorn
  ```
- **SSH (do seu Mac):** precisa da chave `labsuser.pem` (baixe em *AWS Details* no lab):
  ```bash
  chmod 400 labsuser.pem
  ssh -i labsuser.pem ec2-user@54.237.129.141
  ```

---

# Parte 4 — O processo completo, do zero (resumo)

Ordem do que foi feito — e como **reproduzir**:

1. **Código** trazido para o repositório do grupo (monólito Flask + Postgres).
2. **Teste local** com `docker compose up` (app + banco). ✔️
3. **Documentação e diagrama** criados (ARQUITETURA, DEPLOY, diagrama, roteiro).
4. **Terraform** escrito para provisionar VPC + EC2 + RDS + Security Groups.
5. **Credenciais** do Learner Lab configuradas (temporárias, fora do Git).
6. **Descoberta:** o lab bloqueia us-east-2 → deploy feito em **us-east-1**.
7. **`terraform apply`** → 12 recursos criados; a EC2 sobe a app sozinha (user_data).
8. **Validação** dos endpoints contra o IP público (grava/lê no RDS). ✔️
9. **Publicação** no GitHub (sem segredos).

Para reproduzir a infra do zero:
```bash
# 1. credenciais do lab em ~/.aws/credentials (bloco AWS Details > AWS CLI)
# 2. senha do banco por variável de ambiente
export TF_VAR_db_password="uma-senha-forte"
cd infra/terraform
terraform init
terraform apply         # confirme com 'yes'
terraform output        # mostra o IP e a URL
```

---

# Parte 5 — Encerrar e evitar custos 💸

Quando terminar a gravação/avaliação, **derrube tudo** para não gastar horas do lab:

```bash
cd infra/terraform
terraform destroy       # confirme com 'yes' — remove os 12 recursos
```
Ou, no lab, clique em **End Lab**. Confira depois se não sobrou RDS ligado, Elastic IP ocioso
ou snapshot (são as fontes de cobrança silenciosa).

> **Segurança sempre:** as credenciais da AWS **nunca** entram no Git. Neste projeto elas
> ficam só em `~/.aws/credentials` (fora do repositório) e o `.gitignore` bloqueia `.env`,
> `*.tfstate` e `*.tfvars`.
