# ToggleMaster — Tech Challenge Fase 3

Automação do ciclo de vida dos 5 microsserviços com CI/CD, DevSecOps e GitOps. A pasta [`fase2/`](../fase2/README.md) fica como foi entregue, e todo o trabalho novo acontece aqui. A entrega é em 19/01/2027.

## Documentos

- [Guia passo a passo](docs/ToggleMaster_Fase3_Guia_Passo_a_Passo.docx): como baixar, executar e testar o projeto na sua máquina, mesmo sem experiência com Docker ou Kubernetes.
- [Status item por item](docs/ToggleMaster_Fase3_Status_Item_a_Item.docx): o que foi feito, o que já existe e o que falta.

## Situação

| Parte | Estado |
|---|---|
| Serviços, Dockerfiles e Compose local | Prontos, com teste ponta a ponta local aprovado |
| Workflows de CI e DevSecOps | Prontos e testados no GitHub Actions, incluindo a publicação no ECR e a atualização da tag |
| Terraform | Pronto e testado no AWS Academy: cria rede, EKS, 3 RDS, ElastiCache, DynamoDB, SQS, ECR e segredos |
| Manifestos GitOps e Applications do ArgoCD | Prontos e testados no EKS: 10 Applications sincronizadas e os 5 serviços saudáveis |
| Teste ponta a ponta | Aprovado no ambiente local e no EKS, pelo Load Balancer |
| Estimativa de custos, vídeo e relatório | Pendentes |

## Estrutura

```text
.github/workflows/         Na raiz do repositório, como o GitHub exige
  _service-ci.yml          Pipeline reutilizável com todos os estágios
  ci-<serviço>.yml         Um workflow por serviço
fase3/
  <serviço>/               Código e Dockerfile dos 5 serviços
  docs/                    Guia passo a passo e status
  docker-compose.yml       Ambiente local, com portas diferentes das da Fase 2
  gitops/                  Manifestos Kubernetes observados pelo ArgoCD
    argocd/root-app.yaml   Application raiz, que cria todas as outras
    argocd/apps/           Serviços, base do cluster e add-ons
  terraform/               Infraestrutura da AWS, em módulos
  scripts/                 Ambiente local, ambiente da AWS e atualização da tag
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
| Publicação | Push no ECR com tag `v1.0.0-<hash>` | Igual | Só em push ou disparo manual na `main` |
| GitOps | Commit da nova imagem no `deployment.yaml` | Igual | Só depois da publicação |

`gosec` e `bandit` não têm nível crítico, por isso o limite deles é a severidade alta. Em Pull Request, a imagem é construída e analisada, mas não é publicada.

As ferramentas e actions estão fixadas por versão e digest ou SHA. Em março de 2026, a própria [`trivy-action` foi adulterada](https://www.aquasec.com/blog/trivy-supply-chain-attack-what-you-need-to-know) para roubar segredos de pipelines, então nunca troque essas referências por `latest`.

### Demonstração do vídeo

Em um Pull Request, adicione esta linha a `fase3/flag-service/requirements.txt`:

```text
PyYAML==5.3.1
```

A instalação funciona e o passo de SCA reprova com a CVE-2020-14343, de severidade crítica. Para corrigir, troque a linha por `PyYAML==6.0.2`, e o pipeline volta a passar. Não apague a linha: sem nenhuma diferença na pasta do serviço, o filtro de pastas não dispara o workflow de novo no Pull Request. Para mostrar SAST, use `InsecureSkipVerify: true` em um serviço Go ou `subprocess.check_output(cmd, shell=True)` em um serviço Python.

## Configuração no GitHub

Em **Settings > Secrets and variables > Actions**:

| Tipo | Nome | Valor |
|---|---|---|
| Variable | `ECR_REGISTRY` | `<conta>.dkr.ecr.us-east-1.amazonaws.com` |
| Variable | `AWS_REGION` | `us-east-1` |
| Secret | `AWS_ACCESS_KEY_ID` | Credencial da sessão |
| Secret | `AWS_SECRET_ACCESS_KEY` | Credencial da sessão |
| Secret | `AWS_SESSION_TOKEN` | Token da sessão, no AWS Academy |

Sem `ECR_REGISTRY`, a publicação e a atualização da tag são puladas, e o restante do pipeline funciona normalmente. No AWS Academy, os três segredos expiram com a sessão e precisam ser atualizados a cada laboratório.

Para publicar sem alterar a pasta do serviço, abra **Actions**, escolha o workflow do serviço e clique em **Run workflow**, na branch `main`. O botão só aparece depois que os workflows estiverem na `main`.

Em **Settings > Actions > General**, deixe **Workflow permissions** como leitura: o pipeline pede escrita só no job que grava a tag.

**Proteção da `main`:** o commit automático da tag grava direto na `main`, porque os manifestos estão neste mesmo repositório. Segundo relatos da comunidade, o `GITHUB_TOKEN` não pode entrar na lista de exceções da proteção, então confirme isso ao configurar. Por enquanto, bloqueie só force push e exclusão da branch. Para exigir Pull Request, coloque uma deploy key ou um GitHub App na lista de exceções e faça o job da tag usar essa credencial. Se marcar os workflows como verificações obrigatórias, lembre que cada um só roda quando a pasta do serviço muda.

## GitOps

O ArgoCD observa `fase3/gitops/` na `main`. O script `scripts/install-argocd.ps1` instala o ArgoCD com Helm e aplica a Application raiz, que cria todo o restante:

```bash
kubectl apply -f fase3/gitops/argocd/root-app.yaml
```

No teste de 04/11/2026 no EKS, as 10 Applications ficaram `Synced` e `Healthy` em menos de 3 minutos. Depois de um novo commit de tag, o cluster passou a rodar a nova imagem em menos de 1 minuto, sem nenhum `kubectl apply`.

Principais ajustes em relação aos manifestos da Fase 2:

- Os Jobs de banco viraram hooks do ArgoCD e rodam depois dos segredos.
- `evaluation` e `analytics` não têm mais `replicas` no Deployment, para o self-heal não brigar com o HPA.
- O ID da conta saiu dos manifestos: a URL da fila vem do Secrets Manager, e o CI grava a imagem completa. Até o primeiro build, as imagens usam a conta fictícia `000000000000`.
- A chave interna do `evaluation` é semeada pelo Job do `auth`, sem `kubectl exec`.
- O repositório ECR do flag agora se chama `togglemaster/flag-service`.

O ingress-nginx foi mantido por continuidade com a Fase 2, mas o projeto foi aposentado pela comunidade em março de 2026. Vale avaliar a troca se houver tempo.

### Contrato com o Terraform

O Terraform cria os repositórios ECR `togglemaster/<serviço>` e estes segredos no Secrets Manager, com senhas e chaves geradas por ele:

| Segredo | Chaves |
|---|---|
| `togglemaster/auth` | `DATABASE_URL`, `MASTER_KEY`, `SERVICE_API_KEY` |
| `togglemaster/flag` | `DATABASE_URL` |
| `togglemaster/targeting` | `DATABASE_URL` |
| `togglemaster/evaluation` | `REDIS_URL`, `SERVICE_API_KEY`, `AWS_SQS_URL` |
| `togglemaster/analytics` | `AWS_SQS_URL` |

`SERVICE_API_KEY` tem o mesmo valor em `auth` e `evaluation`.

## Ambiente na AWS

O Terraform em `terraform/` cria toda a infraestrutura. No teste de 04/11/2026 no AWS Academy, foram 53 recursos em cerca de 14 minutos.

| Módulo | O que cria |
|---|---|
| `network` | VPC, Internet Gateway, 2 subnets públicas, 2 privadas e as rotas |
| `eks` | Cluster, launch template com hop limit 2 e Node Group |
| `rds` | 3 instâncias PostgreSQL em subnets privadas, uma por serviço |
| `elasticache` | Redis em cluster mode, com TLS, AUTH e criptografia em repouso |
| `messaging` | Tabela `ToggleMasterAnalytics` e fila SQS |
| `ecr` | 5 repositórios `togglemaster/<serviço>` |
| `secrets` | 5 segredos `togglemaster/*` |

Decisões que valem saber:

- **Roles:** o AWS Academy não deixa criar roles. O cluster e os nós usam a `LabRole`, lida por data source. O nome é uma variável, para o mesmo código servir em uma conta pessoal.
- **Rede:** os nós ficam nas subnets públicas, o que dispensa o NAT Gateway e o custo dele. Os bancos e o cache ficam nas subnets privadas e só aceitam conexões vindas do cluster.
- **Estado:** fica em um bucket S3 com versionamento, com bloqueio por `use_lockfile`. O estado guarda as senhas geradas, então o bucket é privado.
- **ArgoCD:** é instalado por Helm, depois do Terraform, pelo script `install-argocd.ps1`.

### Passo a passo

Requer Terraform 1.11 ou mais novo, AWS CLI, `kubectl` e Helm, além das credenciais da AWS configuradas no AWS CLI. Os comandos partem da pasta `fase3`.

```powershell
# 1. Bucket do estado, uma vez por conta. Também grava terraform\backend.hcl.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\aws-bootstrap-state.ps1

# 2. Infraestrutura
Set-Location .\terraform
terraform init "-backend-config=backend.hcl"
terraform apply
Set-Location ..

# 3. No GitHub: cadastre as variáveis e os segredos da seção "Configuração no GitHub"
#    e rode os 5 workflows com Run workflow, na main. Eles publicam as imagens no ECR.

# 4. ArgoCD e Application raiz
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-argocd.ps1

# 5. Teste ponta a ponta pelo Load Balancer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-aws.ps1

# 6. Desmontar tudo, para não gastar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\destroy-aws.ps1
```

Cuidados:

- **Imagens depois de recriar:** o `destroy` apaga os repositórios do ECR com as imagens. Ao recriar o ambiente, rode de novo os 5 workflows antes de instalar o ArgoCD, ou os pods ficam sem imagem.
- **Ordem do `destroy`:** o Load Balancer do ingress é criado pelo Kubernetes, fora do Terraform. O script apaga primeiro as Applications e só depois roda o `terraform destroy`. Sem isso, a exclusão da VPC trava.
- **Credenciais do AWS Academy:** expiram com a sessão. A cada laboratório, atualize o AWS CLI e os 3 segredos do GitHub.
- **Custo:** o ambiente consome créditos enquanto está de pé. Desmonte ao terminar.

## O que falta

- Estimativa de custos no AWS Pricing Calculator, com o print pedido no enunciado.
- Vídeo de até 20 minutos.
- Relatório de entrega.
- Decidir a proteção da `main` e dar acesso de escrita aos demais integrantes.
