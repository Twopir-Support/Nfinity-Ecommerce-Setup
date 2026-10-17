#!/usr/bin/env bash
# NFT Commerce Integration Hub - load (or refresh) the demo data only, no metadata deploy
# Usage:  ./scripts/load-demo-data.sh nft-demo            first load
#         ./scripts/load-demo-data.sh nft-demo --refresh  on demo day: clear orders/shipments/invoices/logs
#                                                          and reload them dated from today
set -euo pipefail
ORG="${1:?Usage: ./scripts/load-demo-data.sh <org-alias> [--refresh]}"
INFO=$(sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization" --target-org "$ORG" --json)
if ! echo "$INFO" | grep -q '"IsSandbox": *true' && ! echo "$INFO" | grep -q 'Developer Edition'; then
  echo "Target org is not a sandbox or Developer Edition. Stopping."; exit 1; fi
if [ "${2:-}" = "--refresh" ]; then
  echo "=== Clear demo transactions ==="; sf apex run --file scripts/apex/reset/clear-demo-transactions.apex --target-org "$ORG"; fi
for f in $(ls scripts/apex/load/*.apex | sort -t/ -k4 -n); do echo "=== Load demo data: $f ==="; sf apex run --file "$f" --target-org "$ORG"; done
echo "=== Verify demo data ==="; sf apex run --file scripts/apex/verify.apex --target-org "$ORG" | grep CHECK || true
echo "Done. Open the dashboard:  sf org open --target-org $ORG --path /lightning/n/NFT_Operations_Home"
