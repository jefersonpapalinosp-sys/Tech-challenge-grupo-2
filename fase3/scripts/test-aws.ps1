# Teste ponta a ponta no EKS: chave, flag, regra, avaliação, fila e gravação no DynamoDB.
# As credenciais vêm do ambiente do AWS CLI, nunca de um arquivo do projeto.
param(
    [string]$BaseUrl,
    [string]$Region = 'us-east-1',
    [string]$SecretPrefix = 'togglemaster',
    [string]$TableName = 'ToggleMasterAnalytics',
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'

if (-not $BaseUrl) {
    $lbHost = kubectl -n ingress-nginx get service ingress-nginx-controller `
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    if ($LASTEXITCODE -ne 0 -or -not $lbHost) {
        throw 'Não encontrei o endereço do Load Balancer. Informe -BaseUrl ou confira o ingress-nginx.'
    }
    $BaseUrl = "http://$lbHost"
}
$BaseUrl = $BaseUrl.TrimEnd('/')
Write-Host "Endereço testado: $BaseUrl"

# A chave mestra é lida do Secrets Manager na hora e não é exibida.
$secretJson = aws secretsmanager get-secret-value --region $Region `
    --secret-id "$SecretPrefix/auth" --query SecretString --output text
if ($LASTEXITCODE -ne 0) { throw "Não foi possível ler o segredo $SecretPrefix/auth." }
$masterKey = ($secretJson | ConvertFrom-Json).MASTER_KEY

function Get-EventCount {
    param([string]$FlagName)

    # O filtro vai em um arquivo temporário, porque o PowerShell altera as aspas do JSON.
    $valuesFile = New-TemporaryFile
    try {
        [IO.File]::WriteAllText($valuesFile.FullName, (@{ ':f' = @{ S = $FlagName } } | ConvertTo-Json -Compress))
        $json = aws dynamodb scan --region $Region --table-name $TableName --select COUNT `
            --filter-expression 'flag_name = :f' `
            --expression-attribute-values "file://$($valuesFile.FullName)" --output json
        if ($LASTEXITCODE -ne 0) { throw 'Não foi possível consultar o DynamoDB.' }
        return [int](($json -join "`n") | ConvertFrom-Json).Count
    } finally {
        Remove-Item $valuesFile.FullName -ErrorAction SilentlyContinue
    }
}

# O Load Balancer leva alguns minutos para responder depois de criado.
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
$healthy = $false
do {
    try {
        $health = Invoke-RestMethod -Uri "$BaseUrl/auth/health" -TimeoutSec 5
        if ($health.status -eq 'ok') { $healthy = $true }
    } catch {
        Start-Sleep -Seconds 5
    }
} while (-not $healthy -and [DateTime]::UtcNow -lt $deadline)
if (-not $healthy) { throw "Timeout aguardando $BaseUrl/auth/health." }
Write-Host '[OK] Auth respondeu pelo Load Balancer'

$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$flagName = "aws-test-$suffix"

$newKey = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/admin/keys" `
    -Headers @{ Authorization = "Bearer $masterKey" } `
    -ContentType 'application/json' `
    -Body (@{ name = "teste-$suffix" } | ConvertTo-Json)
if (-not $newKey.key.StartsWith('tm_key_')) { throw 'O auth-service não retornou uma chave válida.' }
$headers = @{ Authorization = "Bearer $($newKey.key)" }

$validation = Invoke-RestMethod -Uri "$BaseUrl/auth/validate" -Headers $headers
Write-Host "[OK] Auth: $($validation.message)"

$flagBody = @{
    name        = $flagName
    description = 'Flag criada pelo teste ponta a ponta na AWS'
    is_enabled  = $true
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$BaseUrl/flags" -Headers $headers `
    -ContentType 'application/json' -Body $flagBody | Out-Null
Write-Host "[OK] Flag criada: $flagName"

$ruleBody = @{
    flag_name  = $flagName
    is_enabled = $true
    rules      = @{ type = 'PERCENTAGE'; value = 100 }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Method Post -Uri "$BaseUrl/rules" -Headers $headers `
    -ContentType 'application/json' -Body $ruleBody | Out-Null
Write-Host '[OK] Regra de targeting criada (100%)'

$evaluation = Invoke-RestMethod -Uri "$BaseUrl/evaluate?user_id=teste-aws&flag_name=$flagName"
if ($evaluation.result -ne $true) { throw 'A avaliação deveria retornar true para uma regra de 100%.' }
Write-Host '[OK] Evaluation retornou true'

# O evento passa pela fila SQS antes de chegar ao DynamoDB.
$deadline = [DateTime]::UtcNow.AddSeconds(90)
do {
    Start-Sleep -Seconds 3
    $count = Get-EventCount -FlagName $flagName
} while ($count -lt 1 -and [DateTime]::UtcNow -lt $deadline)
if ($count -lt 1) { throw 'O evento não apareceu no DynamoDB dentro do prazo.' }
Write-Host "[OK] Analytics gravou o evento no DynamoDB ($count registro da flag $flagName)"

Write-Host "`nTeste ponta a ponta na AWS concluído com sucesso." -ForegroundColor Green
