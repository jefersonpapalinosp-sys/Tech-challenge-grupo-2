# ToggleMaster — Tech Challenge Fase 2

Implementação local e em AWS da arquitetura de microsserviços descrita no **POSTECH - Tech Challenge - Fase 2**. O relatório final distingue configuração, evidência coletada e itens ainda sem comprovação.

## Código da Fase 2

Este projeto fica na pasta [fase2/](https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2/tree/main/fase2) do repositório do grupo. A raiz mantém o projeto da Fase 1.

```powershell
git clone https://github.com/jefersonpapalinosp-sys/Tech-challenge-grupo-2.git
Set-Location .\Tech-challenge-grupo-2\fase2
```

Os relatórios de entrega e as evidências do laboratório são distribuídos separadamente pela equipe.

## O que está incluído

- 5 microsserviços: `auth`, `flag`, `targeting`, `evaluation` e `analytics`.
- 5 Dockerfiles multi-stage, com processos executados por usuários sem privilégios.
- Docker Compose com exatamente 9 containers: 5 aplicações, 2 PostgreSQL, 1 Redis e 1 LocalStack.
- SQS e DynamoDB totalmente locais pelo LocalStack.
- Teste ponta a ponta: autenticação → flag → targeting → evaluation → SQS → analytics → DynamoDB.
- Manifestos Kubernetes com Namespace, Deployments/StatefulSets, Services, ConfigMap, Secret, Ingress, probes, requests/limits e HPA.
- Scripts PowerShell para build, execução, validação, carga e Kubernetes local.

## Arquitetura local

| Componente | Porta | Dependência de dados |
|---|---:|---|
| auth-service | 18001 → 8001 | PostgreSQL `auth_db` |
| flag-service | 18002 → 8002 | PostgreSQL `flags_db` |
| targeting-service | 18003 → 8003 | PostgreSQL `targeting_db` |
| evaluation-service | 18004 → 8004 | Redis + SQS local |
| analytics-service | 18005 → 8005 | SQS + DynamoDB local |

O segundo PostgreSQL contém dois bancos lógicos, preservando os três bancos isolados pedidos para produção e as duas instâncias exigidas no Compose local.

## Início rápido

Pré-requisito: Docker Desktop em execução com containers Linux.

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-local.ps1
```

O primeiro comando de subida baixa as imagens-base e compila os serviços. Para acompanhar:

```powershell
docker compose ps
docker compose logs -f
```

Para encerrar preservando os dados:

```powershell
.\scripts\stop-local.ps1
```

Para apagar também os volumes locais e recomeçar do zero:

```powershell
.\scripts\stop-local.ps1 -RemoveVolumes
```

## Endpoints

```text
GET  http://localhost:18001/health
POST http://localhost:18001/admin/keys
GET  http://localhost:18001/validate

GET/POST            http://localhost:18002/flags
GET/PUT/DELETE      http://localhost:18002/flags/{name}

POST                http://localhost:18003/rules
GET/PUT/DELETE      http://localhost:18003/rules/{flag_name}

GET  http://localhost:18004/evaluate?user_id=usuario&flag_name=nome-da-flag
GET  http://localhost:18005/health
```

## Kubernetes local

O projeto inclui um cluster isolado com `kind`; não é necessário ativar o Kubernetes do Docker Desktop. A primeira execução baixa o executável local, cria o cluster, instala Metrics Server e Nginx Ingress, carrega as cinco imagens e aplica os manifests:

```powershell
# Preparacao necessaria antes de criar o cluster local:
if (-not (Test-Path .\k8s\secret-local.yaml)) {
    Copy-Item .\k8s\secret-local.example.yaml .\k8s\secret-local.yaml
}
# Edite secret-local.yaml e substitua CHANGE_ME conforme k8s/README.md.
.\scripts\setup-kind.ps1
.\scripts\test-k8s.ps1
kubectl get pods -n togglemaster
kubectl get hpa -n togglemaster
```

O Ingress fica disponível em `http://localhost:18080`, usando o cabeçalho `Host: togglemaster.local`. O script de teste configura esse cabeçalho automaticamente. Para reconstruir e reaplicar depois:

```powershell
.\scripts\deploy-k8s.ps1
```

Consulte [k8s/README.md](k8s/README.md) para os detalhes. A arquitetura, decisões e correspondência com o enunciado estão em [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Docker Compose com recursos AWS

O arquivo `docker-compose.aws.yml` executa somente as cinco aplicações e usa os recursos reais da conta AWS: imagens do ECR, três RDS privados, ElastiCache cluster, SQS e DynamoDB. Ele deve ser executado em um host com rota para a VPC dos bancos e do cache.

```powershell
Copy-Item .env.aws.example .env.aws
# Preencha as senhas, tokens e chaves em .env.aws
docker compose --env-file .env.aws -f docker-compose.aws.yml pull
docker compose --env-file .env.aws -f docker-compose.aws.yml up -d --wait
```

Consulte [docs/COMPOSE-AWS.md](docs/COMPOSE-AWS.md) para endpoints, restrições de rede e preparação dos bancos. O Compose local original permanece inalterado.

## Implantação no EKS

O ambiente AWS Academy atual foi implantado na conta `533267349027`, cluster `ekstogglemaster`, em `us-east-1`, usando ECR, três RDS PostgreSQL, ElastiCache Redis Cluster com TLS, SQS, DynamoDB, Secrets Manager, External Secrets Operator, HPA e Nginx Ingress publicado por um Classic Load Balancer.

Endpoint atual:

```text
http://a5bc56a01f92c4e85887af601f04b84e-1447597342.us-east-1.elb.amazonaws.com
```

Rotas públicas: `/auth`, `/flags`, `/rules` e `/evaluate`. O fluxo Auth → Flag → Targeting → Evaluation → SQS → Analytics → DynamoDB está registrado nas evidências datadas. Consulte [k8s-aws/README.md](k8s-aws/README.md) para a configuração. Os resultados e limites de comprovação constam do relatório entregue separadamente. O endereço observado pode mudar se o Load Balancer for recriado.

## Verificações estáticas

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Esse script valida o Compose, a sintaxe Python e a renderização dos manifestos locais/AWS sem aplicar mudanças ao cluster. Para o Kubernetes local, usa uma cópia temporária com o Secret de exemplo. Arquivos de credenciais do LAB, `.env` reais, kubeconfigs e pacotes privados não fazem parte do repositório; cada integrante deve configurar sua própria sessão AWS.

## Segurança local

As credenciais versionadas são exclusivamente de desenvolvimento local. Produção deve usar um gerenciador de segredos, credenciais rotacionadas e recursos gerenciados (RDS, ElastiCache, DynamoDB e SQS).
