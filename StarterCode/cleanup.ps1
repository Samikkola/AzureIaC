#!/usr/bin/env pwsh
# cleanup.ps1 -- Poistaa kaikki TodoApp Azure-resurssit
# Käyttö: ./cleanup.ps1

$ErrorActionPreference = "Stop"

$rgName = "rg-todoapp-dev"

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "  TodoApp Azure Cleanup" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# Tarkista, onko resource group olemassa
$exists = az group exists --name $rgName
if ($exists -eq "false") {
    Write-Host "Resource Group '$rgName' ei ole olemassa." -ForegroundColor Yellow
    exit 0
}

# Näytä resurssit
Write-Host "Seuraavat resurssit poistetaan:" -ForegroundColor Yellow
Write-Host ""
az resource list --resource-group $rgName --output table
Write-Host ""

# Vahvistus
$confirm = Read-Host "Haluatko varmasti poistaa KAIKKI resurssit? (kirjoita 'delete' vahvistaaksesi)"
if ($confirm -ne "delete") {
    Write-Host "Peruttu." -ForegroundColor Yellow
    exit 0
}

# Poista
Write-Host ""
Write-Host "Poistetaan resource group '$rgName'..." -ForegroundColor Yellow
az group delete --name $rgName --yes --no-wait

Write-Host ""
Write-Host "Poistopyyntö lähetetty! Poistuminen kestää muutaman minuutin." -ForegroundColor Green
Write-Host "Seuraa tilannetta Azure Portalissa tai komennolla:" -ForegroundColor Gray
Write-Host "  az group show --name $rgName --query properties.provisioningState" -ForegroundColor Gray
Write-Host ""