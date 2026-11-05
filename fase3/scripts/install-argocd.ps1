# Instala o ArgoCD no EKS e aplica a Application raiz, que cria todo o restante.
# Rode depois do "terraform apply" e de publicar as imagens no ECR.
param(
    [string]$ClusterName = 'togglemaster',
    [string]$Region = 'us-east-1',
    [string]$ChartVersion = '10.12.1'
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

aws eks update-kubeconfig --region $Region --name $ClusterName | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Não foi possível configurar o kubectl para o cluster $ClusterName." }

# Confere o cluster antes de instalar, para não alterar outro por engano.
$context = kubectl config current-context
if ($context -notlike "*cluster/$ClusterName") {
    throw "O kubectl aponta para '$context', e não para o cluster $ClusterName."
}
Write-Host "[OK] kubectl conectado em $context"

helm upgrade --install argocd argo-cd --version $ChartVersion `
    --repo https://argoproj.github.io/argo-helm `
    --namespace argocd --create-namespace `
    --set dex.enabled=false `
    --set notifications.enabled=false `
    --set applicationSet.enabled=false `
    --wait --timeout 10m
if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar o ArgoCD.' }
Write-Host '[OK] ArgoCD instalado'

kubectl apply -f .\gitops\argocd\root-app.yaml
if ($LASTEXITCODE -ne 0) { throw 'Falha ao aplicar a Application raiz.' }
Write-Host '[OK] Application raiz aplicada'

Write-Host "`nAcompanhe com: kubectl -n argocd get applications"
Write-Host 'Senha do usuário admin:'
Write-Host '  $s = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=''{.data.password}'''
Write-Host '  [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))'
Write-Host 'Interface: kubectl -n argocd port-forward svc/argocd-server 8080:443  e abra https://localhost:8080'
