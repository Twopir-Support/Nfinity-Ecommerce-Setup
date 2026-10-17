# Nfinity E-commerce Setup – NFT Commerce Integration Hub

Salesforce demo app: Shopify and Amazon orders, ShipMonk and Amazon FBA fulfilment,
ShipStation shipments, simulated Accounting Seed invoices and a sync log, all in one app
called **Commerce Integration Hub**. Every component is prefixed **NFT**. All integrations
are simulated and the org is loaded with dummy data. See `docs/ui-reference.html` for
the target screens.

## What is in the repo

| Folder | Contents |
|---|---|
| `force-app/main/default/objects` | 4 NFT objects, 94 NFT fields on 8 objects, list views, compact layouts |
| `force-app/main/default/classes`, `triggers` | Simulation logic (`NFT_CommerceService`), 7 invocable actions, totals triggers, demo-data loader, tests |
| `force-app/main/default/flows`, `quickActions` | 8 screen flows behind the "(Simulated)" buttons |
| `force-app/main/default/lwc/nftOrderLineStatus` | Confirmed / Shipped / Invoiced tiles and line table on the Order page |
| `force-app/main/default/flexipages`, `applications` | Operations home, Order, Product and Account pages, utility bar, the app |
| `force-app/main/default/reports`, `reportTypes`, `dashboards` | 4 report types, 10 reports, 1 dashboard |
| `force-app/main/default/staticresources` | Demo data (dates are offsets from the load day) |
| `scripts/` | One-command deploy, data load, verify and reset |
| `manifest/` | `package-1-core.xml` (data + logic), `package-2-ui.xml` (pages + reports), `package.xml` (everything) |
| `docs/` | UI reference, specs, build notes |

## Deploy from VS Code

1. Install the **Salesforce Extension Pack** in VS Code and the Salesforce CLI
   (`npm install -g @salesforce/cli`).
2. Clone this repo and open the folder in VS Code.
3. Press `Ctrl+Shift+P` → **SFDX: Authorize an Org** → choose Production (for a Developer
   Edition org) or Sandbox → alias `nft-demo` → log in in the browser.
4. Open the VS Code terminal and run:
   - Windows: `./scripts/deploy.ps1 -Org nft-demo`
   - macOS / Linux / Git Bash: `./scripts/deploy.sh nft-demo`

   The script refuses production orgs, then: enables Orders and Path → deploys the core
   metadata → loads the demo data → deploys the pages, app and reports → runs the Apex tests → prints the verification checks.
5. Open the app: `sf org open --target-org nft-demo --path /lightning/n/NFT_Operations_Home`
   and compare with `docs/ui-reference.html`.

Prefer clicking? In VS Code, right-click `manifest/package-1-core.xml` → **SFDX: Deploy
Source in Manifest to Org**, run each file in `scripts/apex/load/` in number order with
**SFDX: Execute Anonymous Apex with Editor Contents**, then deploy
`manifest/package-2-ui.xml` the same way.

## Demo data JSON (`data/`)

The deploy script inserts the demo data from `data/` with `sf data import tree` in the same run.
Manual import: `sf data import tree --plan data/nft-demo-data-plan.json --target-org nft-demo`.
Details: `docs/DEMO-DATA.md`.

## Load or refresh only the demo data

Already deployed? `./scripts/load-demo-data.ps1 -Org nft-demo` (Windows) or
`./scripts/load-demo-data.sh nft-demo`. On the day of a client demo add `-Refresh` / `--refresh`
so "Today" and "24h" dashboard numbers are current. Details: `docs/DEMO-DATA.md`.

## Reset the demo after a rehearsal

Run `scripts/apex/reset/clear-demo-transactions.apex`, then the files in
`scripts/apex/load/` again (steps 2–7). Products, customers and stock go back to the demo values.

## If a deploy step fails

The error names the file and property. Fix it (or ask Claude Code; `CLAUDE.md` tells it
the rules) and rerun the script. The likely spots are listed in `docs/BUILD-NOTES.md`.
