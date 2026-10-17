# NFT Commerce Integration Hub - deploy + load demo data (Windows PowerShell)
# Usage:  ./scripts/deploy.ps1 -Org nft-demo
param([Parameter(Mandatory = $true)][string]$Org)
$ErrorActionPreference = "Stop"
function Step($label, [scriptblock]$cmd) {
    Write-Host "`n=== $label ===" -ForegroundColor Cyan
    & $cmd
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $label" -ForegroundColor Red; exit 1 }
}
# Safety: refuse production
$org = sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization" --target-org $Org --json | ConvertFrom-Json
$rec = $org.result.records[0]
if (-not $rec.IsSandbox -and $rec.OrganizationType -ne "Developer Edition") {
    Write-Host "Target org is not a sandbox or Developer Edition. Stopping." -ForegroundColor Red; exit 1
}
Write-Host "Target org: $Org ($($rec.OrganizationType), sandbox=$($rec.IsSandbox))"
Step "1/6 Enable Orders and Path" { sf project deploy start --source-dir force-app/main/default/settings --target-org $Org --wait 20 }
Step "2/6 Deploy core: objects, fields, Apex, flows, actions, LWC, data files" { sf project deploy start --manifest manifest/package-1-core.xml --target-org $Org --wait 60 }
Write-Host "`n=== 2/6 Assign permission set NFT_Commerce_Hub_Access ===" -ForegroundColor Cyan
sf org assign permset --name NFT_Commerce_Hub_Access --target-org $Org; if ($LASTEXITCODE -ne 0) { Write-Host "(already assigned)" }
function ApexLoad {
    Get-ChildItem scripts/apex/load/*.apex | Sort-Object { [int]($_.Name.Split('-')[0]) } | ForEach-Object {
        $f = $_.FullName
        Step "3/6 Load demo data (Apex upsert): $($_.Name)" { sf apex run --file $f --target-org $Org }
    }
}
# Demo data: JSON tree import (data/) into an empty org; Apex upsert loader if demo data already exists or the import fails
$existing = (sf data query -q "SELECT COUNT() FROM Order WHERE NFT_External_Order_Id__c != null" --target-org $Org --json | ConvertFrom-Json).result.totalSize
if ($existing -eq 0) {
    if (Get-Command node -ErrorAction SilentlyContinue) { node scripts/build-demo-data.js }
    else { Write-Host "node not found: importing data/ with the dates it was generated for" -ForegroundColor Yellow }
    Write-Host "`n=== 3/6 Import demo data: data/nft-demo-data-plan.json ===" -ForegroundColor Cyan
    sf data import tree --plan data/nft-demo-data-plan.json --target-org $Org
    if ($LASTEXITCODE -eq 0) { Step "3/6 Recalculate totals" { sf apex run --file scripts/apex/load/7-finish.apex --target-org $Org } }
    else { Write-Host "Tree import failed; completing with the Apex loader (upserts, no duplicates)" -ForegroundColor Yellow; ApexLoad }
} else { ApexLoad }
Step "4/6 Deploy UI: pages, app, utility bar, path, reports, dashboard" { sf project deploy start --manifest manifest/package-2-ui.xml --target-org $Org --wait 60 }
Write-Host "`n=== 4/6 Assign permission set NFT_Commerce_Hub_App ===" -ForegroundColor Cyan
sf org assign permset --name NFT_Commerce_Hub_App --target-org $Org; if ($LASTEXITCODE -ne 0) { Write-Host "(already assigned)" }
Step "5/6 Run Apex tests" { sf apex run test --class-names NFT_CommerceTests --target-org $Org --wait 20 --result-format human }
Step "6/6 Verify demo data" { sf apex run --file scripts/apex/verify.apex --target-org $Org | Select-String "CHECK" }
Write-Host "`nDone. Open the app:  sf org open --target-org $Org --path /lightning/n/NFT_Operations_Home" -ForegroundColor Green
