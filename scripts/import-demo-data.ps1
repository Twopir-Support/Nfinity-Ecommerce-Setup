# NFT Commerce Integration Hub - insert all demo data in one shot (Windows PowerShell)
# Usage:  ./scripts/import-demo-data.ps1 -Org nft-demo
# Empty org      -> JSON tree import of data/ (re-dated to today), then totals
# Data exists    -> clear demo transactions and reload with the Apex upsert loader (no duplicates)
param([Parameter(Mandatory = $true)][string]$Org)
$ErrorActionPreference = "Stop"
function Step($label, [scriptblock]$cmd) {
    Write-Host "`n=== $label ===" -ForegroundColor Cyan
    & $cmd
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $label" -ForegroundColor Red; exit 1 }
}
function ApexLoad {
    Get-ChildItem scripts/apex/load/*.apex | Sort-Object { [int]($_.Name.Split('-')[0]) } | ForEach-Object {
        $f = $_.FullName
        Step "Load demo data (Apex upsert): $($_.Name)" { sf apex run --file $f --target-org $Org }
    }
}
# Safety: refuse production
$rec = (sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization" --target-org $Org --json | ConvertFrom-Json).result.records[0]
if (-not $rec.IsSandbox -and $rec.OrganizationType -ne "Developer Edition") {
    Write-Host "Target org is not a sandbox or Developer Edition. Stopping." -ForegroundColor Red; exit 1
}
Write-Host "`n=== Assign permission set NFT_Commerce_Hub_Access ===" -ForegroundColor Cyan
sf org assign permset --name NFT_Commerce_Hub_Access --target-org $Org; if ($LASTEXITCODE -ne 0) { Write-Host "(already assigned)" }

$existing = (sf data query -q "SELECT COUNT() FROM Order WHERE NFT_External_Order_Id__c != null" --target-org $Org --json | ConvertFrom-Json).result.totalSize
if ($existing -eq 0) {
    if (Get-Command node -ErrorAction SilentlyContinue) { Step "Re-date data/ to today" { node scripts/build-demo-data.js } }
    else { Write-Host "node not found: importing data/ with the dates it was generated for" -ForegroundColor Yellow }
    Write-Host "`n=== Import data/nft-demo-data-plan.json (2,921 records) ===" -ForegroundColor Cyan
    sf data import tree --plan data/nft-demo-data-plan.json --target-org $Org
    if ($LASTEXITCODE -eq 0) { Step "Recalculate totals" { sf apex run --file scripts/apex/load/7-finish.apex --target-org $Org } }
    else { Write-Host "Tree import failed part-way; completing with the Apex loader (upserts, no duplicates)" -ForegroundColor Yellow; ApexLoad }
} else {
    Write-Host "Org already has $existing demo orders: clearing and reloading dated today" -ForegroundColor Yellow
    Step "Clear demo transactions" { sf apex run --file scripts/apex/reset/clear-demo-transactions.apex --target-org $Org }
    ApexLoad
}
Step "Verify demo data" { sf apex run --file scripts/apex/verify.apex --target-org $Org | Select-String "CHECK" }
Write-Host "`nDone. Open the dashboard:  sf org open --target-org $Org --path /lightning/n/NFT_Operations_Home" -ForegroundColor Green
