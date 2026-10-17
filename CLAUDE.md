# CLAUDE.md – NFT Commerce Integration Hub (built repo)

This repo already contains the built Salesforce metadata. Your job in this repo is to
deploy it to the user's org, fix deploy errors, and keep everything NFT-prefixed.

Rules:
1. Every component you create or rename starts with `NFT` (API names `NFT_…`, LWC `nft…`).
   Never modify or delete components that do not start with NFT.
2. Before any deploy, run `sf data query -q "SELECT IsSandbox, OrganizationType FROM Organization"`
   and stop unless it is a sandbox or Developer Edition. Never deploy to production.
3. Deploy with `scripts/deploy.ps1 -Org <alias>` (Windows) or `scripts/deploy.sh <alias>`.
4. On a deploy error: read the full error, fix only the named file, redeploy that phase's
   manifest, continue. Record every fix in `docs/BUILD-NOTES.md` under "Fixes applied".
5. Orders stay in standard Status `Draft`; lifecycle uses `NFT_Fulfillment_Status__c`.
6. After deploy, run `scripts/apex/verify.apex`; every CHECK line must read PASS.
7. Commit after each successful fix with a message starting `NFT:`.

Design reference: `docs/ui-reference.html`. Specs: `docs/specs/`. Differences: `docs/BUILD-NOTES.md`.
