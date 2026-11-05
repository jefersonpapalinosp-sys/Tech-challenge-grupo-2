# Cria o bucket S3 que guarda o estado do Terraform e grava terraform/backend.hcl.
# O bucket precisa existir antes do primeiro "terraform init", porque o Terraform
# não consegue guardar o estado em um bucket que ele mesmo ainda vai criar.
param(
    [string]$Region = 'us-east-1'
)

$ErrorActionPreference = 'Stop'
$terraformDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'terraform'

$account = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or -not $account) {
    throw 'Sem acesso à AWS. Confira as credenciais com "aws sts get-caller-identity".'
}

# O ID da conta deixa o nome único em toda a AWS.
$bucket = "togglemaster-tfstate-$account"

$existing = aws s3api list-buckets --query "Buckets[?Name=='$bucket'].Name" --output text
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível listar os buckets.' }
if ($existing -eq $bucket) {
    Write-Host "[OK] O bucket $bucket já existe."
} else {
    if ($Region -eq 'us-east-1') {
        aws s3api create-bucket --bucket $bucket --region $Region | Out-Null
    } else {
        aws s3api create-bucket --bucket $bucket --region $Region `
            --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível criar o bucket $bucket." }
    Write-Host "[OK] Bucket $bucket criado."
}

# O versionamento permite voltar a um estado anterior se algo der errado.
aws s3api put-bucket-versioning --bucket $bucket --versioning-configuration Status=Enabled
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível ligar o versionamento.' }

aws s3api put-public-access-block --bucket $bucket `
    --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível bloquear o acesso público.' }
Write-Host '[OK] Versionamento ligado e acesso público bloqueado.'

$backendFile = Join-Path $terraformDir 'backend.hcl'
[IO.File]::WriteAllText($backendFile, "bucket = `"$bucket`"`n")
Write-Host "[OK] Arquivo gravado: $backendFile"
Write-Host "`nPróximo passo, dentro da pasta terraform: terraform init -backend-config=backend.hcl"
