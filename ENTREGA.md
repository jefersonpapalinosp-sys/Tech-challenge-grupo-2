# Relatório de Entrega — Tech Challenge Fase 1 · ToggleMaster

> Grupo 2 · Curso de DevOps

## 1. Participantes

| Nome | RM / Matrícula | Função no grupo |
| :--- | :------------- | :-------------- |
| _preencher_ | | |
| _preencher_ | | |
| _preencher_ | | |
| _preencher_ | | |

## 2. Links da entrega

| Item | Link |
| :--- | :--- |
| 🎥 Vídeo de demonstração (até 15 min) | _colar o link (YouTube não listado / Drive)_ |
| 🧭 Diagrama de arquitetura | Editável: [docs/arquitetura.drawio](docs/arquitetura.drawio) · versão no repo: [ARQUITETURA.md](ARQUITETURA.md) · _(opcional: link Miro/draw.io publicado)_ |
| 🎬 Roteiro do vídeo | [docs/ROTEIRO-VIDEO.md](docs/ROTEIRO-VIDEO.md) |
| 💻 Repositório | https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2 |

## 3. Arquitetura da solução

Resumo da arquitetura implantada (detalhes em [ARQUITETURA.md](ARQUITETURA.md)):

- **VPC** dedicada `10.0.0.0/16` com 2 subnets públicas em AZs distintas.
- **EC2 t3.micro** (Amazon Linux 2023) rodando a API Flask via Gunicorn (Docker) na porta 5000.
- **RDS PostgreSQL** `db.t3.micro`, não público, acessível apenas pela EC2.
- **Security Groups** aplicando menor privilégio: a porta 5432 do RDS só aceita tráfego do SG da EC2.

## 4. Como foi feito o deploy

- [ ] Manual pelo AWS Console — passo-a-passo em [DEPLOY.md](DEPLOY.md)
- [x] **Automatizado com Terraform** — [infra/terraform/](infra/terraform/)

Provisionado no **AWS Academy Learner Lab** (conta `537132640408`, role `voclabs`) via
`terraform apply` — **12 recursos** criados de uma vez (VPC, 2 subnets, IGW, route table,
2 Security Groups, DB Subnet Group, RDS e EC2). A EC2 sobe a aplicação automaticamente pelo
`user_data` (Docker build + run apontando para o RDS).

> **Observação de região:** o lab **bloqueia us-east-2** (Ohio) para EC2/VPC
> (`UnauthorizedOperation`). As regiões liberadas são **us-east-1** e us-west-2 — por isso o
> deploy foi feito em **us-east-1** (N. Virginia).

### Recursos provisionados (evidência)

| Item | Valor |
| :--- | :---- |
| Região | `us-east-1` |
| URL da aplicação | http://54.237.129.141:5000 |
| Health check | http://54.237.129.141:5000/health → `{"status":"ok"}` |
| IP público EC2 | `54.237.129.141` (instância `i-000c923085ffa7de1`, t3.micro) |
| Endpoint RDS | `togglemaster-db.cpr3sig84ykp.us-east-1.rds.amazonaws.com` (não público) |
| VPC | `vpc-090d321e9f286e710` (10.0.0.0/16) |
| Key pair (SSH) | `vockey` |

> ⚠️ O IP público muda a cada `stop/start` da EC2. Se o lab reiniciar, rode
> `terraform apply` de novo (ou `terraform output`) para pegar o novo IP.

## 5. Evidências

_Insira prints/links comprovando:_

- [ ] Aplicação rodando localmente com Docker (`curl localhost:5000/health`).
- [ ] Instância EC2 no ar com IP público.
- [ ] RDS criado e conectado (resposta dos endpoints `/flags`).
- [ ] Configuração dos Security Groups (regra 5432 apontando para o SG da EC2).

## 6. Desafios encontrados e decisões tomadas

_(Preencha com a experiência real do grupo. Exemplos de pontos a comentar:)_

- **Rede/RDS:** o DB Subnet Group exige 2 AZs — como resolvemos.
- **Segurança:** por que a regra do banco referencia o SG da EC2 em vez de um IP.
- **Persistência do processo:** por que usamos Docker `--restart always` (ou systemd) em vez
  de rodar o Gunicorn no foreground.
- **Custos:** cuidados tomados para não gerar cobrança (Free Tier, destruição dos recursos).
- **Monólito:** vantagens e desvantagens observadas na prática.

## 7. Como derrubar a infraestrutura

- Manual: seguir a seção "Limpeza" do [DEPLOY.md](DEPLOY.md).
- Terraform: `cd infra/terraform && terraform destroy`.

---

_Checklist final antes de enviar: vídeo publicado e acessível · diagrama linkado · nomes
preenchidos · credenciais NÃO versionadas · recursos AWS derrubados após a avaliação._
