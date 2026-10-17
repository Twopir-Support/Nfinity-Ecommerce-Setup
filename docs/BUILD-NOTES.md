# Build notes: what was built and how it differs from the specs

The specs in `docs/specs/` describe the design. This repo is the built version. Where the
build differs, the reason is below. Nothing here has been deployed yet; statuses are
updated after the first deploy.

## Differences from the specs

| Spec said | Built as | Why |
|---|---|---|
| 12 flows, logic in Flow elements, no Apex | 8 thin screen flows (the buttons) that call 7 Apex invocable actions; 4 Apex triggers for totals | Hand-written Flow XML for loops and DML cannot be validated before deploy; Apex is testable (`NFT_CommerceTests`) and the flows stay simple. Users still click the same buttons. |
| Record-triggered flows F9–F11 | Triggers `NFT_InventoryBalanceTrigger`, `NFT_OrderTrigger`, `NFT_OrderItemTrigger`, `NFT_SyncLogTrigger` via `NFT_TriggerHandler` | Same results (product totals, customer totals, failed-sync count), bulk-safe. Triggers only act on NFT demo orders (External Order ID set). |
| Product2 `Family` picklist values | New field `NFT_Family__c` | Avoids changing the standard Family picklist. |
| Data load via CSV + `sf data upsert` | Apex loader `NFT_DemoDataLoader` reading 7 static resources | One command per step, dates computed from today inside Salesforce, idempotent upserts. |
| Dashboard running user = deploying user | Dashboard runs as the logged-in viewer (`LoggedInUser`) | No username in the repo. Developer Edition allows a small number of dynamic dashboards; if the org refuses it, change `dashboardType` to `SpecifiedUser` and add `<runningUser>your@username</runningUser>`. |
| Account sidebar "At-Risk Orders" | "Open Orders by Must Ship By" (sorted ascending, shows Alert column) | Dynamic related list filters are not reliably deployable; the sort puts at-risk orders first. |
| Field history tracking on Order | Not enabled | Needs the standard object's history setting; not needed for the demo. |

## Components that may need a small fix on first deploy

These were written from the Metadata API formats but could not be validated against an
org before pushing. If one fails, the deploy error names the file and property:

1. Lightning pages (`flexipages/`): property names of `lst:dynamicRelatedList`,
   `flexipage:tabset`, `flexipage:dashboard`, `flexipage:reportChart`, and the utility bar
   flow items.
2. List view columns for standard fields (`ORDERS.ORDER_NUMBER`, `SALES.ACCOUNT.NAME`,
   `ORDERS.TOTAL_AMOUNT`, `ACCOUNT.NAME`).
3. Report columns and filters on the custom report types.
4. `settings/PathAssistant.settings-meta.xml` field name.

They are all in the UI phase (`manifest/package-2-ui.xml`) except list views, so the
objects, logic and demo data deploy and load first either way.

## Fixes applied

### Validation 0Afbm00000jxWef (2026-10-17) – 156 component errors

| Component | Error | Fix |
|---|---|---|
| `NFT_ConfirmOrderAction`, `NFT_DeliverOrderAction`, `NFT_FbaSyncAction`, `NFT_PostInvoiceAction`, `NFT_ShipOrderAction`, `NFT_SimulateOrderAction` | Line 6: `Unexpected token '@'`, `Invalid type: required`, `Invalid constructor name: InvocableVariable` (then line 13 `InvocableMethod methods do not support parameter type of List`) | Removed `required=true` from the `@InvocableVariable` on the Request class. The org's compiler rejected it; `NFT_RetrySyncAction` (no `required`) compiled fine. The screen flows always pass the Id, so behaviour is unchanged. |
| `NFT_CommerceTests` | `Constructor not defined: [NFT_…Action.Request].()` | Follow-on error from the six classes above; no change needed. |
| `NFT_DemoDataLoader` | Line 19 `Unexpected token 'list'`, `Identifier name is reserved` and follow-on errors on every caller | Helper method `list(...)` renamed to `items(...)`; `list` is a reserved word in Apex. |
| `NFT_Orders` (report type) | `Could not find field AccountId in table Order` | Removed the `AccountId` column; `Account.Name` and `Account.Id` remain. |
| 7 reports in `NFT_Demo_Reports` | `invalid report type` | Follow-on error from `NFT_Orders`; no change needed. |
| `NFT_Commerce_Operations` (dashboard) | `Metric … component missing indicatorLowColor attribute` | Added `indicatorHighColor` / `indicatorLowColor` / `indicatorMiddleColor` to the 6 metric components. |
| `NFT_Commerce_Hub_Utility_Bar` (flexipage) | `The parent Lightning page one__UtilityBar doesn't exist` | Removed `parentFlexiPage`; utility bars don't need one. |
| `NFT_Commerce_Integration_Hub` (app) | `no FlexiPage named NFT_Commerce_Hub_Utility_Bar found` | Follow-on error from the utility bar; no change needed. |
| `NFT_Order_Fulfillment_Path` (path) | `Cannot create more than 1 Path per sobjectType and recordType` | The org already has a Path on Order (Master), and we don't change non-NFT components. Removed from `manifest/package.xml` and `manifest/package-2-ui.xml` and added to `.forceignore`. To use it: in Setup → Path Settings, deactivate/delete the existing Order path, then deploy `force-app/main/default/pathAssistants/NFT_Order_Fulfillment_Path.pathAssistant-meta.xml` on its own (remove the `.forceignore` line first) or create the path by hand on `NFT_Fulfillment_Status__c`. |
