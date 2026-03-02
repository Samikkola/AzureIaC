#!/usr/bin/env pwsh
# deploy.ps1 -- TodoApp Azure Deployment Script
# Käyttö: ./deploy.ps1

#Get assembly
Add-Type -AssemblyName System.IO.Compression.FileSystem

param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TodoApp Azure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ─── 1. TARKISTA ESIVAATIMUKSET ───

Write-Host "[1/7] Tarkistetaan esivaatimukset..." -ForegroundColor Yellow

# Tarkista Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "VIRHE: Azure CLI ei ole asennettu!" -ForegroundColor Red
    Write-Host "Asenna: winget install Microsoft.AzureCLI" -ForegroundColor Gray
    exit 1
}

# Tarkista .NET SDK
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "VIRHE: .NET SDK ei ole asennettu!" -ForegroundColor Red
    exit 1
}

# Tarkista kirjautuminen
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Ei kirjautuneena Azureen. Kirjaudutaan..." -ForegroundColor Yellow
    az login
    $account = az account show | ConvertFrom-Json
}

Write-Host "  Kirjautuneena: $($account.user.name)" -ForegroundColor Green
Write-Host ""

# ─── 2. VALITSE SUBSCRIPTION ───

Write-Host "[2/7] Valitse Azure-subscription:" -ForegroundColor Yellow
Write-Host ""

$subscriptions = az account list --query "[].{Name:name, Id:id, IsDefault:isDefault}" | ConvertFrom-Json

for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    $sub = $subscriptions[$i]
    $marker = if ($sub.IsDefault) { " (nykyinen)" } else { "" }
    Write-Host "  [$i] $($sub.Name)$marker" -ForegroundColor White
}

Write-Host ""
$selection = Read-Host "Valitse numero (Enter = nykyinen)"

if ($selection -ne "") {
    $selectedSub = $subscriptions[[int]$selection]
    az account set --subscription $selectedSub.Id
    Write-Host "  Subscription asetettu: $($selectedSub.Name)" -ForegroundColor Green
} else {
    $selectedSub = $subscriptions | Where-Object { $_.IsDefault -eq $true }
    Write-Host "  Käytetään nykyistä: $($selectedSub.Name)" -ForegroundColor Green
}
Write-Host ""

# ─── 3. KYSY SALASANA ───

Write-Host "[3/7] PostgreSQL-salasana:" -ForegroundColor Yellow

if (-not $env:DB_PASSWORD) {
    $securePassword = Read-Host "  Anna PostgreSQL admin -salasana" -AsSecureString
    $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}
Write-Host "  Salasana asetettu" -ForegroundColor Green
Write-Host ""

# ─── 4. WHAT-IF ESIKATSELU ───

Write-Host "[4/7] Infrastruktuurin esikatselu (what-if)..." -ForegroundColor Yellow
Write-Host ""

az deployment sub what-if `
    --location northeurope `
    --template-file infra/main.bicep `
    --parameters infra/main.bicepparam

Write-Host ""
$confirm = Read-Host "Haluatko jatkaa deploymenttia? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Deployment peruttu." -ForegroundColor Yellow
    exit 0
}
Write-Host ""

# ─── 5. DEPLOY INFRASTRUKTUURI ───

Write-Host "[5/7] Deploydaan infrastruktuuri Bicepilla..." -ForegroundColor Yellow

$deploymentName = "deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$ErrorActionPreference = "SilentlyContinue"
$rawOutput = az deployment sub create `
    --location northeurope `
    --template-file infra/main.bicep `
    --parameters infra/main.bicepparam `
    --name $deploymentName `
    --query properties.outputs `
    --output json 2>&1
$azExitCode = $LASTEXITCODE
$ErrorActionPreference = "Stop"

if ($azExitCode -ne 0) {
    Write-Host "ERROR: Deployment failed (exit code $azExitCode)." -ForegroundColor Red
    $rawOutput | ForEach-Object { Write-Host $_ }
    exit 1
}

# Filter out non-JSON lines (e.g. "Bicep CLI is already installed...", warnings)
$jsonString = ($rawOutput | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
$firstBrace = $jsonString.IndexOf('{')
if ($firstBrace -ge 0) {
    $deployment = $jsonString.Substring($firstBrace) | ConvertFrom-Json
} else {
    Write-Host "ERROR: Deployment returned no output." -ForegroundColor Red
    $rawOutput | ForEach-Object { Write-Host $_ }
    exit 1
}

$rgName = $deployment.resourceGroupName.value
$webAppName = $deployment.webAppName.value
$webAppUrl = $deployment.webAppUrl.value

Write-Host ""
Write-Host "  Resource Group:  $rgName" -ForegroundColor Green
Write-Host "  PostgreSQL:      $($deployment.postgresServerFqdn.value)" -ForegroundColor Green
Write-Host "  Web App:         $webAppName" -ForegroundColor Green
Write-Host "  URL:             $webAppUrl" -ForegroundColor Green
Write-Host ""

# ─── 6. NÄYTÄ RESURSSIT JA JULKAISE SOVELLUS ───

Write-Host "[6/7] Luodut Azure-resurssit:" -ForegroundColor Yellow
Write-Host ""

az resource list --resource-group $rgName --output table

Write-Host ""
Write-Host "Julkaistaan .NET-sovellus App Serviceen..." -ForegroundColor Yellow
Write-Host ""

# Käännä sovellus
Write-Host "  Käännetään sovellus (dotnet publish)..." -ForegroundColor Gray
dotnet publish TodoApi/TodoApi.csproj -c Release -o ./publish --nologo --verbosity quiet

# Paketoi ZIP-tiedostoksi (manually create ZIP with forward slashes for Linux compatibility)
Write-Host "  Paketoidaan ZIP-tiedostoksi..." -ForegroundColor Gray
if (Test-Path ./publish.zip) { Remove-Item ./publish.zip }
Add-Type -AssemblyName System.IO.Compression
$publishPath = (Resolve-Path ./publish).Path
$zipPath = Join-Path (Get-Location) "publish.zip"
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $files = Get-ChildItem -Path $publishPath -Recurse -File
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($publishPath.Length + 1)
        $entryName = $relativePath.Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $file.FullName, $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $zip.Dispose()
}

# Lähetä App Serviceen (zip deploy)
Write-Host "  Lähetetään App Serviceen (zip deploy)..." -ForegroundColor Gray
az webapp deploy `
    --resource-group $rgName `
    --name $webAppName `
    --src-path ./publish.zip `
    --type zip

# Siivoa väliaikaiset tiedostot
Remove-Item -Recurse -Force ./publish
Remove-Item ./publish.zip

Write-Host "  Sovellus julkaistu!" -ForegroundColor Green
Write-Host ""

# ─── 7. VALMIS ───

Write-Host "========================================" -ForegroundColor Green
Write-Host "  Deployment valmis!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Sovelluksen URL:  $webAppUrl" -ForegroundColor Cyan
Write-Host "  Swagger UI:      $webAppUrl/swagger" -ForegroundColor Cyan
Write-Host "  Health check:    $webAppUrl/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Huom: Ensimmäinen käynnistys voi kestää 1-2 minuuttia." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Ympäristömuuttujat (App Settings) asetettu Bicepillä:" -ForegroundColor Yellow
Write-Host "    ConnectionStrings__DefaultConnection = Host=psql-...;..." -ForegroundColor Gray
Write-Host "    ASPNETCORE_ENVIRONMENT = Development" -ForegroundColor Gray
Write-Host ""
Write-Host "  Siivoa resurssit kun olet valmis:" -ForegroundColor Yellow
Write-Host "  ./cleanup.ps1" -ForegroundColor Gray
Write-Host ""