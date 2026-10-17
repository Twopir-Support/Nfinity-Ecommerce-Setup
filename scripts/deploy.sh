#!/usr/bin/env bash
# NFT Commerce Integration Hub - deploy + load demo data (macOS / Linux / Git Bash)
# Usage:  ./scripts/deploy.sh nft-demo
set -euo pipefail
ORG="${1:?Usage: ./scripts/deploy.sh <org-alias>}"
INFO=$(sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization" --target-org "$ORG" --json)
if ! echo "$INFO" | grep -q '"IsSandbox": *true' && ! echo "$INFO" | grep -q 'Developer Edition'; then
  echo "Target org is not a sandbox or Developer Edition. Stopping."; exit 1; fi
echo "=== 1/6 Enable Orders and Path ===";  sf project deploy start --source-dir force-app/main/default/settings --target-org "$ORG" --wait 20
echo "=== 2/6 Deploy core metadata ===";    sf project deploy start --manifest manifest/package-1-core.xml --target-org "$ORG" --wait 60
echo "=== 2/6 Assign permission set NFT_Commerce_Hub_Access ==="; sf org assign permset --name NFT_Commerce_Hub_Access --target-org "$ORG" || echo "(already assigned)"
apex_load() { for f in $(ls scripts/apex/load/*.apex | sort -t/ -k4 -n); do echo "=== 3/6 Load demo data (Apex upsert): $f ==="; sf apex run --file "$f" --target-org "$ORG"; done; }
# Demo data: JSON tree import (data/) into an empty org; Apex upsert loader if demo data already exists or the import fails
if sf data query -q "SELECT COUNT() FROM Order WHERE NFT_External_Order_Id__c != null" --target-org "$ORG" --json | grep -q '"totalSize": *0'; then
  if command -v node >/dev/null; then node scripts/build-demo-data.js; else echo "node not found: importing data/ with the dates it was generated for"; fi
  echo "=== 3/6 Import demo data: data/nft-demo-data-plan.json ==="
  if sf data import tree --plan data/nft-demo-data-plan.json --target-org "$ORG"; then
    sf apex run --file scripts/apex/load/7-finish.apex --target-org "$ORG"
  else echo "Tree import failed; completing with the Apex loader (upserts, no duplicates)"; apex_load; fi
else apex_load; fi
echo "=== 4/6 Deploy UI metadata ===";      sf project deploy start --manifest manifest/package-2-ui.xml --target-org "$ORG" --wait 60
echo "=== 4/6 Assign permission set NFT_Commerce_Hub_App ==="; sf org assign permset --name NFT_Commerce_Hub_App --target-org "$ORG" || echo "(already assigned)"
echo "=== 5/6 Run Apex tests ===";          sf apex run test --class-names NFT_CommerceTests --target-org "$ORG" --wait 20 --result-format human
echo "=== 6/6 Verify demo data ===";        sf apex run --file scripts/apex/verify.apex --target-org "$ORG" | grep CHECK || true
echo "Done. Open the app:  sf org open --target-org $ORG --path /lightning/n/NFT_Operations_Home"
