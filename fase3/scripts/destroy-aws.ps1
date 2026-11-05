# Desmonta o ambiente da AWS na ordem certa. O Load Balancer é criado pelo Kubernetes,
# fora do Terraform. Se ele ficar de pé, o "terraform destroy" trava ao apagar a VPC.
param(
    [string]$ClusterName = 'togglemaster',
    [string]$Region = 'us-east-1',
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$terraformDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'terraform'

$clusters = aws eks list-clusters --region $Region --query 'clusters' --output text
if ($LASTEXITCODE -ne 0) { throw 'Sem acesso à AWS. Confira as credenciais.' }

if (($clusters -split '\s+') -contains $ClusterName) {
    aws eks update-kubeconfig --region $Region --name $ClusterName | Out-Null
    $context = kubectl config current-context
    if ($context -notlike "*cluster/$ClusterName") {
        throw "O kubectl aponta para '$context', e não para o cluster $ClusterName."
    }

    # Apagar a Application raiz remove as outras, e com elas o Service do ingress.
    $apps = kubectl -n argocd get applications -o name --ignore-not-found
    if ($apps) {
        Write-Host 'Apagando as Applications do ArgoCD...'
        kubectl -n argocd delete application togglemaster --ignore-not-found --timeout=10m
        if ($LASTEXITCODE -ne 0) { throw 'A Application raiz não foi apagada dentro do prazo.' }
    }

    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    do {
        $services = kubectl get services --all-namespaces `
            -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
        if ($services) {
            Write-Host "Aguardando a remoção de: $($services -join ', ')"
            Start-Sleep -Seconds 15
        }
    } while ($services -and [DateTime]::UtcNow -lt $deadline)
    if ($services) { throw 'Ainda há Services do tipo LoadBalancer no cluster.' }
    Write-Host '[OK] Nenhum Load Balancer criado pelo Kubernetes'
} else {
    Write-Host "O cluster $ClusterName não existe. Seguindo direto para o Terraform."
}

Set-Location $terraformDir
if ($AutoApprove) {
    terraform destroy -input=false -auto-approve
} else {
    terraform destroy
}
if ($LASTEXITCODE -ne 0) { throw 'O terraform destroy falhou. Leia a mensagem acima.' }
Write-Host "`nAmbiente removido. O bucket do estado do Terraform continua, de propósito." -ForegroundColor Green
