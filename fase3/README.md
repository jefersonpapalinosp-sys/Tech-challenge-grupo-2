# ToggleMaster — Tech Challenge Fase 3

Automação do ciclo de vida dos 5 microsserviços com CI/CD, DevSecOps e GitOps. A pasta [`fase2/`](../fase2/README.md) fica como foi entregue, e todo o trabalho novo acontece aqui. A entrega é em 19/01/2027.

## Documentos

- [Guia passo a passo](docs/ToggleMaster_Fase3_Guia_Passo_a_Passo.docx): como baixar, executar e testar o projeto na sua máquina e na AWS, mesmo sem experiência com Docker ou Kubernetes.
- [Status item por item](docs/ToggleMaster_Fase3_Status_Item_a_Item.docx): o que foi feito, o que já existe e o que falta.

## Situação

| Parte | Estado |
|---|---|
| Serviços, Dockerfiles e Compose local | Prontos, com teste ponta a ponta local aprovado |
| Workflows de CI e DevSecOps | Prontos e testados no GitHub Actions, incluindo a publicação no ECR e a atualização da tag |
| Terraform | Pronto e testado no AWS Academy: cria rede, EKS, 3 RDS, ElastiCache, DynamoDB, SQS, ECR e segredos |
| Manifestos GitOps e Applications do ArgoCD | Prontos e testados no EKS: 10 Applications sincronizadas e os 5 serviços saudáveis |
| Teste ponta a ponta | Aprovado no ambiente local e no EKS, pelo Load Balancer |
| Ambiente na AWS | Desmontado em 04/11/2026, depois do teste. Só resta o bucket do estado. `ECR_REGISTRY` e os 3 segredos foram removidos do GitHub, então o pipeline hoje só constrói e analisa, sem publicar. Para recriar, siga o passo a passo da seção Ambiente na AWS |
| Estimativa de custos e relatório de entrega | Prontos, fora do repositório. A estimativa no AWS Pricing Calculator deu 226,63 USD por mês |
| Vídeo | Falta gravar e publicar, e depois preencher o link e a duração no relatório e no documento de entrega |

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

Cada serviço tem um workflow, disparado em Pull Request e em push na `main` que altere a pasta dele, a configuração de lint da linguagem (`.flake8` ou `.golangci.yml`), o próprio workflow ou o `_service-ci.yml`. Também pode ser disparado à mão, com **Run workflow**. Uma alteração no `_service-ci.yml` dispara os 5 workflows.

| Estágio | Go | Python | Bloqueia em |
|---|---|---|---|
| Build e testes | `go build`, `go test` | `pip install`, `compileall` e, se houver `test_*.py`, `pytest` | Qualquer falha |
| Lint | golangci-lint | flake8 | Qualquer apontamento |
| SCA | Trivy `fs` | Trivy `fs` | Vulnerabilidade crítica |
| SAST | gosec | bandit | Severidade alta |
| Imagem | `docker build`, Trivy `image` | `docker build`, Trivy `image` | Vulnerabilidade crítica |
| Publicação | Push no ECR com tag `v1.0.0-<hash>` | Igual | Só em push ou disparo manual na `main` |
| GitOps | Commit da nova imagem no `deployment.yaml` | Igual | Só depois da publicação |

`gosec` e `bandit` não têm nível crítico, por isso o limite deles é a severidade alta. Em Pull Request, a imagem é construída e analisada, mas não é publicada.

Hoje só o `evaluation-service` tem testes unitários (`main_test.go`). Nos outros quatro serviços, o estágio de build e testes compila o código e, nos serviços Python, também instala as dependências.

As actions estão fixadas por SHA, as imagens do Trivy e do golangci-lint por versão e digest, e gosec, flake8 e bandit por versão. O `pytest` não tem versão fixada, mas só é instalado se o serviço tiver `test_*.py`, o que não ocorre hoje. O pipeline usa a imagem `aquasec/trivy`, e não a `trivy-action`. Em março de 2026, [um ataque à cadeia de distribuição do Trivy](https://www.aquasec.com/blog/trivy-supply-chain-attack-what-you-need-to-know) adulterou tags dessa action e imagens do Trivy para roubar segredos de pipelines, então nunca troque essas referências por `latest`.

### Demonstração do vídeo

Em um Pull Request, adicione esta linha a `fase3/flag-service/requirements.txt`:

```text
PyYAML==5.3.1
```

A instalação funciona e o passo de SCA reprova com a CVE-2020-14343, de severidade crítica. Para corrigir, troque a linha por `PyYAML==6.0.2`. Em teste local, essa versão instala sem erro e passa no Trivy, então o pipeline deve voltar a passar. Ensaie antes de gravar, porque um novo alerta crítico pode reprovar o pipeline sem mudança no código. Não apague a linha: sem nenhuma diferença na pasta do serviço, o filtro de pastas não dispara o workflow de novo no Pull Request. Para mostrar SAST, adicione código que compile e passe no lint, porque o SAST só roda depois desses estágios. No `flag-service`, corrija antes o PyYAML, porque o SCA roda primeiro no mesmo job. Em Go, acrescente `InsecureSkipVerify: true` ao `tls.Config` de `evaluation-service/main.go`, com o alinhamento do `gofmt`. Em Python, adicione `import subprocess` e `subprocess.check_output(cmd, shell=True)`, com `cmd` em uma variável definida antes.

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

Situação atual: desde o teste de 04/11/2026, só `AWS_REGION` continua cadastrada. `ECR_REGISTRY` e os 3 segredos foram removidos, então hoje o pipeline só constrói e analisa. Para publicar de novo, recadastre esses 4 itens depois do `terraform apply`.

Para publicar sem alterar a pasta do serviço, com `ECR_REGISTRY` e os segredos cadastrados, abra **Actions**, escolha o workflow do serviço e clique em **Run workflow**, na branch `main`.

Em **Settings > Actions > General**, deixe **Workflow permissions** como leitura: o pipeline pede escrita só no job que grava a tag.

**Proteção da `main`:** o commit automático da tag grava direto na `main`, porque os manifestos estão neste mesmo repositório. Segundo relatos da comunidade, o `GITHUB_TOKEN` não pode entrar na lista de exceções da proteção, então confirme isso ao configurar. Por enquanto, bloqueie só force push e exclusão da branch. Para exigir Pull Request, coloque uma deploy key ou um GitHub App na lista de exceções e faça o job da tag usar essa credencial. Se marcar os workflows como verificações obrigatórias, lembre que cada um só roda quando muda a pasta do serviço, a configuração de lint da linguagem, o próprio workflow ou o `_service-ci.yml`.

## GitOps

O ArgoCD observa `fase3/gitops/` na `main`. O script `scripts/install-argocd.ps1` instala o ArgoCD com Helm e aplica a Application raiz, que cria todo o restante:

```bash
kubectl apply -f fase3/gitops/argocd/root-app.yaml
```

Nos dois ciclos do teste de 04/11/2026 no EKS, as 10 Applications ficaram `Synced` e `Healthy` em 2,5 e 4,6 minutos. Depois de um novo commit de tag, o ArgoCD concluiu a sincronização cerca de 1 minuto depois, sem nenhum `kubectl apply`.

Principais ajustes em relação aos manifestos da Fase 2:

- Os Jobs de banco viraram hooks do ArgoCD e rodam depois dos segredos.
- `evaluation` e `analytics` não têm mais `replicas` no Deployment, para o self-heal não brigar com o HPA.
- A URL da fila saiu dos manifestos e vem do Secrets Manager. O ID da conta aparece só na imagem, que o CI grava completa no `deployment.yaml` a partir de `ECR_REGISTRY`. Hoje a `main` aponta para as imagens do teste de 04/11/2026, que foram apagadas com o ambiente. Ao recriar o ambiente, mesmo em outra conta, os 5 workflows publicam as imagens e regravam esse endereço.
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

O Terraform em `terraform/` cria toda a infraestrutura. Em 04/11/2026, o ciclo completo rodou duas vezes no AWS Academy: 53 recursos criados em 14,1 e 12,3 minutos, e removidos em 12,2 e 13,5 minutos.

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
# 1. Bucket do estado. Só cria o bucket na primeira vez e grava terraform\backend.hcl, que não vai para o Git. Repita em um clone novo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\aws-bootstrap-state.ps1

# 2. Infraestrutura
Set-Location .\terraform
terraform init "-backend-config=backend.hcl"
terraform apply
Set-Location ..

# 3. No GitHub: cadastre as variáveis e os segredos da seção "Configuração no GitHub". O valor de ECR_REGISTRY é a saída ecr_registry do Terraform.
#    Rode os 5 workflows com Run workflow, na main, e espere terminarem. Eles publicam as imagens no ECR e gravam a nova tag nos manifestos.

# 4. ArgoCD e Application raiz
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-argocd.ps1

# Repita até as 10 Applications ficarem Synced e Healthy. No teste, levou de 2,5 a 4,6 minutos.
kubectl -n argocd get applications

# 5. Teste ponta a ponta pelo Load Balancer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-aws.ps1

# 6. Desmontar o ambiente, para não gastar. O bucket do estado continua, de propósito.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\destroy-aws.ps1
```

Cuidados:

- **Imagens depois de recriar:** o `destroy` apaga os repositórios do ECR com as imagens. Ao recriar o ambiente, rode de novo os 5 workflows antes de instalar o ArgoCD, ou os pods ficam sem imagem.
- **Ordem do `destroy`:** o Load Balancer do ingress é criado pelo Kubernetes, fora do Terraform. O script apaga primeiro as Applications e só depois roda o `terraform destroy`. Sem isso, a exclusão da VPC trava.
- **Depois de desmontar:** apague a variável `ECR_REGISTRY` no GitHub. Com ela cadastrada, o próximo push na `main` tenta publicar em um ECR que não existe mais, e o pipeline falha. Sem ela, o pipeline só constrói e analisa.
- **Credenciais do AWS Academy:** expiram com a sessão. A cada laboratório, atualize o AWS CLI e os 3 segredos do GitHub.
- **Custo:** o ambiente consome créditos enquanto está de pé. Desmonte ao terminar.

## O que falta

- Recriar o ambiente na AWS, gravar e publicar o vídeo de até 20 minutos.
- Preencher o link e a duração do vídeo no relatório e no documento de entrega, e exportar os PDFs de novo.
- Decidir a proteção da `main` e dar acesso de escrita aos demais integrantes.
