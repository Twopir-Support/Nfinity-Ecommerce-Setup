#!/usr/bin/env bash
# NFT Commerce Integration Hub - insert all demo data in one shot (macOS / Linux / Git Bash)
# Usage:  ./scripts/import-demo-data.sh nft-demo
# Empty org      -> JSON tree import of data/ (re-dated to today), then totals
# Data exists    -> clear demo transactions and reload with the Apex upsert loader (no duplicates)
set -euo pipefail
ORG="${1:?Usage: ./scripts/import-demo-data.sh <org-alias>}"
INFO=$(sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization" --target-org "$ORG" --json)
if ! echo "$INFO" | grep -q '"IsSandbox": *true' && ! echo "$INFO" | grep -q 'Developer Edition'; then
  echo "Target org is not a sandbox or Developer Edition. Stopping."; exit 1; fi
apex_load() { for f in $(ls scripts/apex/load/*.apex | sort -t/ -k4 -n); do echo "=== Load demo data (Apex upsert): $f ==="; sf apex run --file "$f" --target-org "$ORG"; done; }
echo "=== Assign permission set NFT_Commerce_Hub_Access ==="; sf org assign permset --name NFT_Commerce_Hub_Access --target-org "$ORG" || echo "(already assigned)"
if sf data query -q "SELECT COUNT() FROM Order WHERE NFT_External_Order_Id__c != null" --target-org "$ORG" --json | grep -q '"totalSize": *0'; then
  if command -v node >/dev/null; then node scripts/build-demo-data.js; else echo "node not found: importing data/ with the dates it was generated for"; fi
  echo "=== Import data/nft-demo-data-plan.json (2,921 records) ==="
  if sf data import tree --plan data/nft-demo-data-plan.json --target-org "$ORG"; then
    sf apex run --file scripts/apex/load/7-finish.apex --target-org "$ORG"
  else echo "Tree import failed part-way; completing with the Apex loader (upserts, no duplicates)"; apex_load; fi
else
  echo "Org already has demo orders: clearing and reloading dated today"
  sf apex run --file scripts/apex/reset/clear-demo-transactions.apex --target-org "$ORG"; apex_load
fi
echo "=== Verify demo data ==="; sf apex run --file scripts/apex/verify.apex --target-org "$ORG" | grep CHECK || true
echo "Done. Open the dashboard:  sf org open --target-org $ORG --path /lightning/n/NFT_Operations_Home"
