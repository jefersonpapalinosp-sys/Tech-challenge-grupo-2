# Roteiro do Vídeo de Demonstração (até 15 min)

Guia com tempos, o que mostrar na tela e o que falar. Cobre todos os itens exigidos:
demo local, diagrama, app na EC2 conectada ao RDS e os Security Groups.

> **Antes de gravar (checklist):**
> - [ ] AWS Learner Lab com **Start Lab** ativo (bolinha verde) e console na região **us-east-1**.
> - [ ] App local pronto para subir (`docker compose up`). No macOS, desligue o *Receptor AirPlay* para liberar a porta 5000.
> - [ ] Diagrama aberto (`docs/arquitetura.drawio` no [draw.io](https://app.diagrams.net)).
> - [ ] Postman/terminal com os `curl` de teste prontos.
> - [ ] Confirme o IP público atual: `cd infra/terraform && terraform output`.

---

## 0:00 – 1:00 · Abertura
- **Tela:** README do repositório no GitHub.
- **Fala:** "Somos o Grupo 2. Este é o Tech Challenge Fase 1 — a plataforma ToggleMaster,
  uma API de *feature flags* em Flask + PostgreSQL, que vamos rodar localmente e implantar na AWS."
- Apresente rapidamente os integrantes.

## 1:00 – 3:30 · Aplicação rodando localmente (Docker)
- **Tela:** terminal na raiz do projeto.
- **Comandos:**
  ```bash
  docker compose up --build -d
  curl http://localhost:5000/health
  ```
- **Fala:** explique que o Compose sobe **dois containers** — a API e o PostgreSQL — e que o
  `entrypoint.sh` espera o banco, cria a tabela `flags` (`flask init-db`) e sobe o Gunicorn.
- Mostre 1–2 endpoints (`POST /flags`, `GET /flags`) para provar que funciona.
- Finalize: `docker compose down`.

## 3:30 – 6:30 · Diagrama de arquitetura
- **Tela:** `docs/arquitetura.drawio` aberto no draw.io.
- **Fala — percorra o fluxo:**
  1. Cliente → **Internet Gateway** → **EC2** (porta 5000).
  2. **EC2** (Gunicorn/Docker) → **RDS PostgreSQL** (porta 5432).
  3. **VPC dedicada** 10.0.0.0/16 com 2 subnets públicas em 2 AZs (o RDS exige 2 AZs).
- **Decisões (cite ao menos 3):** monólito no MVP; RDS gerenciado vs. Postgres na EC2;
  EC2 em vez de ECS nesta fase; RDS **não público**.
- **Custos:** dentro do **Free Tier / AWS Academy** o custo é ~US$ 0 (t3.micro + db.t3.micro).

## 6:30 – 11:00 · Aplicação rodando na AWS (EC2 + RDS)
- **Tela:** console AWS na região **us-east-1**.
- **Mostre:** a instância **EC2** (`togglemaster-app`) com IP público, e o **RDS**
  (`togglemaster-db`) com status *Available* e **Publicly accessible = No**.
- **Tela:** terminal. Rode a bateria contra o IP público (troque `<IP>`):
  ```bash
  IP=<IP-PUBLICO-EC2>
  curl http://$IP:5000/health
  curl -X POST -H "Content-Type: application/json" \
    -d '{"name":"demo-video","is_enabled":true}' http://$IP:5000/flags
  curl http://$IP:5000/flags
  curl -X PUT -H "Content-Type: application/json" \
    -d '{"is_enabled":false}' http://$IP:5000/flags/demo-video
  curl http://$IP:5000/flags/demo-video
  ```
- **Fala:** "O `GET` e o `POST` funcionam porque a EC2 está conectada ao RDS — os dados são
  gravados e lidos do banco gerenciado, não de um banco local."
- (Opcional) SSH na EC2 e `docker logs togglemaster` para mostrar o Gunicorn e o "Banco disponível!".

## 11:00 – 13:30 · Segurança (Security Groups)
- **Tela:** EC2 → Security Groups.
- **Mostre `sg-togglemaster-web`:** entrada 5000 (0.0.0.0/0) e 22 (SSH).
- **Mostre `sg-togglemaster-db`:** entrada 5432 **cuja origem é o SG-web**, não um IP.
- **Fala — o ponto-chave:** "O banco só aceita conexão vinda da EC2. Mesmo que alguém
  descubra o endpoint do RDS, não consegue conectar de fora da VPC. É o princípio do
  **menor privilégio**." Cite também `publicly_accessible = false`.

## 13:30 – 15:00 · Encerramento
- **Fala:** recapitule — monólito rodando na nuvem, RDS gerenciado, rede e segurança
  configuradas. Cite o **Terraform** ([infra/terraform/](../infra/terraform/)) como
  automação bônus de toda a infra.
- Mencione o cuidado com **custos**: os recursos serão destruídos após a avaliação
  (`terraform destroy` / End Lab).
- Agradeça e encerre.

---

## Falas de reserva (se algo falhar ao vivo)
- **Porta 5000 ocupada (macOS):** "É o Receptor AirPlay; em produção isso não ocorre" —
  ou mostre em `localhost:5001` (override local).
- **500 nos `/flags`:** indica conexão com o RDS — mostre a regra 5432 do SG e o endpoint.
- **IP mudou:** rode `terraform output` para pegar o IP atual (muda a cada stop/start da EC2).
