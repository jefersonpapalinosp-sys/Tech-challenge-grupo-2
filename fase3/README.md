# ToggleMaster — Tech Challenge Fase 3

Automação do ciclo de vida dos 5 microsserviços com CI/CD, DevSecOps e GitOps. A pasta [`fase2/`](../fase2/README.md) fica como foi entregue, e todo o trabalho novo acontece aqui.

## Situação

| Parte | Estado |
|---|---|
| Serviços, Dockerfiles e Compose local | Prontos, com teste ponta a ponta local aprovado |
| Workflows de CI e DevSecOps | Prontos; a publicação no ECR e a atualização da tag só rodam com a AWS configurada |
| Manifestos GitOps e Applications do ArgoCD | Prontos; a execução na AWS ainda não foi testada |
| Terraform | Pendente: precisa da conta AWS definida para ser testado |
| Vídeo e relatório | Pendentes |

## Estrutura

```text
.github/workflows/         Na raiz do repositório, como o GitHub exige
  _service-ci.yml          Pipeline reutilizável com todos os estágios
  ci-<serviço>.yml         Um workflow por serviço
fase3/
  <serviço>/               Código e Dockerfile dos 5 serviços
  docker-compose.yml       Ambiente local, com portas diferentes das da Fase 2
  gitops/                  Manifestos Kubernetes observados pelo ArgoCD
    argocd/root-app.yaml   Application raiz, que cria todas as outras
    argocd/apps/           Serviços, base do cluster e add-ons
  scripts/                 Ambiente local e atualização da tag
```

## Ambiente local

Requer Docker Desktop. Não usa AWS e pode rodar ao lado da Fase 2.

```powershell
Set-Location .\fase3
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-local.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-local.ps1 -RemoveVolumes
```

## Pipeline

Cada serviço tem um workflow, disparado em todo Pull Request e em push na `main` que altere a pasta dele.

| Estágio | Go | Python | Bloqueia em |
|---|---|---|---|
| Build e testes | `go build`, `go test` | `pip install`, `compileall` | Qualquer falha |
| Lint | golangci-lint | flake8 | Qualquer apontamento |
| SCA | Trivy `fs` | Trivy `fs` | Vulnerabilidade crítica |
| SAST | gosec | bandit | Severidade alta |
| Imagem | `docker build`, Trivy `image` | `docker build`, Trivy `image` | Vulnerabilidade crítica |
| Publicação | Push no ECR com tag `v1.0.0-<hash>` | Igual | Só em push na `main` |
| GitOps | Commit da nova imagem no `deployment.yaml` | Igual | Só depois da publicação |

`gosec` e `bandit` não têm nível crítico, por isso o limite deles é a severidade alta. Em Pull Request, a imagem é construída e analisada, mas não é publicada.

As ferramentas e actions estão fixadas por versão e digest ou SHA. Em março de 2026, a própria [`trivy-action` foi adulterada](https://www.aquasec.com/blog/trivy-supply-chain-attack-what-you-need-to-know) para roubar segredos de pipelines, então nunca troque essas referências por `latest`.

### Demonstração do vídeo

Em um Pull Request, adicione esta linha a `fase3/flag-service/requirements.txt`:

```text
PyYAML==5.3.1
```

A instalação funciona e o passo de SCA reprova com a CVE-2020-14343, de severidade crítica. Remova a linha e o pipeline volta a passar. Para mostrar SAST, use `InsecureSkipVerify: true` em um serviço Go ou `subprocess.check_output(cmd, shell=True)` em um serviço Python.

## Configuração no GitHub quando a AWS estiver pronta

Em **Settings > Secrets and variables > Actions**:

| Tipo | Nome | Valor |
|---|---|---|
| Variable | `ECR_REGISTRY` | `<conta>.dkr.ecr.us-east-1.amazonaws.com` |
| Variable | `AWS_REGION` | `us-east-1` |
| Secret | `AWS_ACCESS_KEY_ID` | Credencial da sessão |
| Secret | `AWS_SECRET_ACCESS_KEY` | Credencial da sessão |
| Secret | `AWS_SESSION_TOKEN` | Token da sessão, no AWS Academy |

Sem `ECR_REGISTRY`, a publicação e a atualização da tag são puladas, e o restante do pipeline funciona normalmente. No AWS Academy, os três segredos expiram com a sessão e precisam ser atualizados a cada laboratório.

Em **Settings > Actions > General**, deixe **Workflow permissions** como leitura: o pipeline pede escrita só no job que grava a tag.

**Proteção da `main`:** ao exigir Pull Request, libere o GitHub Actions para gravar na `main` ou o commit da tag será recusado, porque os manifestos estão neste mesmo repositório. Se marcar os workflows como verificações obrigatórias, lembre que cada um só roda quando a pasta do serviço muda.

## GitOps

O ArgoCD observa `fase3/gitops/` na `main`. A instalação do ArgoCD fica para a etapa com AWS. Depois dela, um único comando cria todo o restante:

```bash
kubectl apply -f fase3/gitops/argocd/root-app.yaml
```

Principais ajustes em relação aos manifestos da Fase 2:

- Os Jobs de banco viraram hooks do ArgoCD e rodam depois dos segredos.
- `evaluation` e `analytics` não têm mais `replicas` no Deployment, para o self-heal não brigar com o HPA.
- O ID da conta saiu dos manifestos: a URL da fila vem do Secrets Manager, e o CI grava a imagem completa. Até o primeiro build, as imagens usam a conta fictícia `000000000000`.
- A chave interna do `evaluation` é semeada pelo Job do `auth`, sem `kubectl exec`.
- O repositório ECR do flag agora se chama `togglemaster/flag-service`.

O ingress-nginx foi mantido por continuidade com a Fase 2, mas o projeto foi aposentado pela comunidade em março de 2026. Vale avaliar a troca se houver tempo.

### Contrato com o Terraform

O Terraform precisa criar os repositórios ECR `togglemaster/<serviço>` e estes segredos no Secrets Manager:

| Segredo | Chaves |
|---|---|
| `togglemaster/auth` | `DATABASE_URL`, `MASTER_KEY`, `SERVICE_API_KEY` |
| `togglemaster/flag` | `DATABASE_URL` |
| `togglemaster/targeting` | `DATABASE_URL` |
| `togglemaster/evaluation` | `REDIS_URL`, `SERVICE_API_KEY`, `AWS_SQS_URL` |
| `togglemaster/analytics` | `AWS_SQS_URL` |

`SERVICE_API_KEY` precisa ter o mesmo valor em `auth` e `evaluation`.

## Pendências com AWS

- Terraform com backend remoto no S3: rede, EKS e Node Group com hop limit 2, 3 RDS, ElastiCache, DynamoDB, SQS, ECR e segredos.
- Instalação do ArgoCD no cluster.
- Adaptar o teste ponta a ponta da Fase 2 (`fase2/scripts/test-aws-deployment.ps1`), que depende de um arquivo local de credenciais.
- Estimativa de custos, vídeo e relatório.
