# NFT Commerce Integration Hub - load (or refresh) the demo data only, no metadata deploy (Windows PowerShell)
# Usage:  ./scripts/load-demo-data.ps1 -Org nft-demo            first load
#         ./scripts/load-demo-data.ps1 -Org nft-demo -Refresh   on demo day: clear orders/shipments/invoices/logs
#                                                                and reload them dated from today
param([Parameter(Mandatory = $true)][string]$Org, [switch]$Refresh)
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
if ($Refresh) { Step "Clear demo transactions" { sf apex run --file scripts/apex/reset/clear-demo-transactions.apex --target-org $Org } }
Get-ChildItem scripts/apex/load/*.apex | Sort-Object { [int]($_.Name.Split('-')[0]) } | ForEach-Object {
    $f = $_.FullName
    Step "Load demo data: $($_.Name)" { sf apex run --file $f --target-org $Org }
}
Step "Verify demo data" { sf apex run --file scripts/apex/verify.apex --target-org $Org | Select-String "CHECK" }
Write-Host "`nDone. Open the dashboard:  sf org open --target-org $Org --path /lightning/n/NFT_Operations_Home" -ForegroundColor Green
