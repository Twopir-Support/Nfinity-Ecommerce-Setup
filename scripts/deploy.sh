#!/usr/bin/env bash
# NFT Commerce Integration Hub - deploy + load demo data (macOS / Linux / Git Bash)
# Usage:  ./scripts/deploy.sh nft-demo
set -euo pipefail
ORG="${1:?Usage: ./scripts/deploy.sh <org-alias>}"
INFO=$(sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization" --target-org "$ORG" --json)
if ! echo "$INFO" | grep -q '"IsSandbox": *true' && ! echo "$INFO" | grep -q 'Developer Edition'; then
  echo "Target org is not a sandbox or Developer Edition. Stopping."; exit 1; fi
echo "=== 1/7 Enable Orders and Path ===";  sf project deploy start --source-dir force-app/main/default/settings --target-org "$ORG" --wait 20
echo "=== 2/7 Deploy core metadata ===";    sf project deploy start --manifest manifest/package-1-core.xml --target-org "$ORG" --wait 60
for f in $(ls scripts/apex/load/*.apex | sort -t/ -k4 -n); do echo "=== 3/7 Load demo data: $f ==="; sf apex run --file "$f" --target-org "$ORG"; done
echo "=== 4/7 Deploy UI metadata ===";      sf project deploy start --manifest manifest/package-2-ui.xml --target-org "$ORG" --wait 60
echo "=== 5/7 Assign permission set ===";   sf org assign permset --name NFT_Commerce_Hub_User --target-org "$ORG"
echo "=== 6/7 Run Apex tests ===";          sf apex run test --class-names NFT_CommerceTests --target-org "$ORG" --wait 20 --result-format human
echo "=== 7/7 Verify demo data ===";        sf apex run --file scripts/apex/verify.apex --target-org "$ORG" | grep CHECK || true
echo "Done. Open the app:  sf org open --target-org $ORG --path /lightning/n/NFT_Operations_Home"
