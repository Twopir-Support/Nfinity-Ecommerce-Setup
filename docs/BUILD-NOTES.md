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

### Validation 2 (2026-10-17) – 48 component errors

| Component | Error | Fix |
|---|---|---|
| `NFT_Inventory_Balance__c.NFT_Product__c` | `Cannot add a lookup relationship child with cascade or restrict options to Product2` | Delete constraint changed from `Restrict` to `SetNull` and `required` set to `false` (SetNull lookups can't be required). The page layout still marks it Required, and the demo loader always sets it. |
| List views `NFT_All_Stock` and `NFT_Low_Stock`, report type `NFT_Inventory_Balances`, the Inventory Balance layout, `NFT_CommerceService`, `NFT_CommerceTests`, `NFT_DemoDataLoader`, `NFT_TriggerHandler`, all 4 triggers, the 7 `NFT_…Action` classes, all 8 flows, report `NFT_Low_Stock_SKUs` | `no CustomField named NFT_Product__c`, `Dependent class is invalid`, `We can't find the NFT_…Action action` | Follow-on errors from `NFT_Product__c`; no change needed. |
| Reports `NFT_Customer_Orders_by_Channel`, `NFT_FBA_Orders_Last_30_Days`, `NFT_New_Orders_Today`, `NFT_Orders_by_Channel_This_Month` | `You can't include groupings in the selected columns list` | Removed the grouping field from each report's columns. |
| Report `NFT_Customer_Orders_by_Channel` | `chart-legendPosition: Invalid value specified: Right` | Removed `legendPosition` from this horizontal bar chart. It has only one grouping, so there's no legend to place. |
| Dashboard `NFT_Commerce_Operations` | `no Report named NFT_Demo_Reports/NFT_New_Orders_Today found` | Follow-on error from the report; no change needed. |
| Lightning pages (Account, Order, Product, Operations Home, Utility Bar) | `region … specifies mode 'REPLACE' but a parent region enabling that mode doesn't exist` | Removed `<mode>Replace</mode>` from every region. It only applies to pages that extend a parent page. |
| `NFT_Operations_Home` | `couldn't retrieve the design time component information for component flexipage:dashboard` | Component changed to `desktopDashboards:embeddedDashboard`, which is the standard Dashboard component. |
| `NFT_Commerce_Hub_User` (permission set) | `no ApexClass named NFT_CommerceService found` | **Removed the permission set from the project at the owner's request** (two new permission sets were added later; see "Permission sets added back"). The file was deleted, it was taken out of both manifests, and the "Assign permission set" step was removed from `deploy.sh` and `deploy.ps1` (now 6 steps). Access now comes from the users' profiles. Custom objects use Public Read/Write sharing. |

### Validation 3 (2026-10-17) – 4 component errors

| Component | Error | Fix |
|---|---|---|
| `NFT_Account_Record_Page`, `NFT_Order_Record_Page`, `NFT_Product_Record_Page` | `[lst:dynamicRelatedList] attribute [parentFieldApiName]: Could not find entity [null]` | `parentFieldApiName` must name the page's own record as `Object.Id`. It is now `Account.Id`, `Order.Id` and `Product2.Id` (it held the child's lookup field before). |
| `NFT_Commerce_Hub_Utility_Bar` | `Invalid property [height] in component [flowruntime:interview]` | Removed `height` and `width` from the 3 flow utility items, so panels use the default size. They can be resized in App Manager → Utility Items. |

### Validation 4 (2026-10-17) – 4 component errors

| Component | Error | Fix |
|---|---|---|
| `NFT_Account_Record_Page` | `[lst:dynamicRelatedList] attribute [relatedListFieldAliases]: Could not find column [OrderNumber] in related list [Orders]` | Standard fields in a dynamic related list use the related-list column names, not field API names. Orders columns are now `ORDERS.ORDER_NUMBER`, `ORDERS.TOTAL_AMOUNT`, `ORDERS.EFFECTIVE_DATE` (also the sort field on the Orders tab). Contacts columns are now `FULL_NAME`, `CONTACT.EMAIL`, `CONTACT.PHONE1`. Custom fields (`NFT_…__c`) stay as API names. |
| `NFT_Commerce_Hub_Utility_Bar` | `Invalid property [icon] in component [flowruntime:interview]` | `icon` and `label` belong to the utility item, not the flow component, so they now have `<type>decorator</type>`. |
| `NFT_Order_Record_Page` | `[relatedListDisplayType]: The related lists display value you entered is invalid` | Shipments list changed from `TILE` (not a valid value) to `ADVGRID`, like the other lists. |
| `NFT_Product_Record_Page` | `[relatedListApiName]: Could not find related list [OrderItems] for entity [Product2]` | Product2 has no Order Products related list (OrderItem links to the product through the price book entry). The "Open order lines" tab and its list were removed. The page keeps the "Stock by location" and "Details" tabs. |

### Validation 5 (2026-10-17) – 2 component errors

| Component | Error | Fix |
|---|---|---|
| `NFT_Account_Record_Page` | `Invalid property [refreshButton] in component [flexipage:reportChart]` | Removed `refreshButton`. The valid property `showRefreshButton` was already on the component. |
| `NFT_Product_Record_Page` | `Component [flexipage:fieldSection] attribute [columns]: count [4] exceeded max [2]` | The "Stock totals" section now has 2 columns with 2 fields each (On Hand + Reserved, Available + Inbound) instead of 4 single-field columns. |

Also added `scripts/load-demo-data.sh` / `.ps1` to load the demo data without a metadata deploy,
with a refresh option for demo day, and `docs/DEMO-DATA.md` listing the records and dashboard values.

### Demo data as JSON tree-import files (2026-10-17)

- Added `data/` (one JSON file per object + `nft-demo-data-plan.json`, 2,921 records) and
  `scripts/build-demo-data.js`, which generates it from the `NFT_DemoData_*` static resources with dates
  from the demo day.
- `deploy.sh` / `deploy.ps1` step 3 now imports `data/` with `sf data import tree` into an empty org,
  falling back to the Apex upsert loader when demo data exists or the import fails.
- `NFT_OrderTrigger` and `NFT_OrderItemTrigger` got a `before insert` step
  (`NFT_TriggerHandler.defaultPricebook` / `defaultPricebookEntries`): NFT orders and lines inserted without a
  price book get the Standard Price Book, and missing standard prices are created from the line price.
  Covered by the new test `NFT_CommerceTests.importedOrderGetsStandardPricebook`.

### Validation 6 (2026-10-17) – 7 component errors

| Component | Error | Fix |
|---|---|---|
| `NFT_TriggerHandler` | `Identifier name is reserved: activate (116:30)` | Local list renamed from `activate` to `toActivate`; `activate` is a reserved word in Apex. |
| `NFT_DemoDataLoader`, all 4 `NFT_…Trigger`s | `Dependent class is invalid`, `Variable does not exist: NFT_TriggerHandler` | Follow-on errors from `NFT_TriggerHandler`; no change needed. |
| `NFT_Account_Record_Page` | `[flexipage:reportChart] attribute [reportFilter]: Unknown filter: AccountId` | Removed the "Customer Orders by Channel" report chart from the page. Without the account filter it would show every customer's orders. The page keeps the Open Orders and Orders lists. To add the chart back: App Builder → Report Chart → report `NFT_Customer_Orders_by_Channel` → pick the Account filter from the drop-down, which lists the valid values for this org. |

### Permission sets added back (2026-10-17)

The 5 NFT tabs (Operations, NFT Inventory Balances, NFT Shipments, NFT Sync Logs, NFT Invoices) did not show
in the app: new tabs deploy as Hidden for every profile, and the project had no profile or permission set.
At the user's request two permission sets were added. Neither references Apex, so the old
`no ApexClass named NFT_CommerceService` error cannot recur.

| Permission set | Phase | Gives |
|---|---|---|
| `NFT_Commerce_Hub_Access` | core (`package-1-core.xml`) | Create/Read/Edit/Delete/View All/Modify All on the 4 NFT objects; read + edit on 70 NFT fields and read on 21 formula/roll-up fields (Account, Order, Order Product, Product and the NFT objects); the 4 object tabs Visible. Required and master-detail fields are left out (always accessible). |
| `NFT_Commerce_Hub_App` | UI (`package-2-ui.xml`) | The `NFT_Commerce_Integration_Hub` app and the Operations tab Visible. |

`deploy.sh` / `deploy.ps1` assign `NFT_Commerce_Hub_Access` right after the core deploy (so the JSON data import
has field access) and `NFT_Commerce_Hub_App` after the UI deploy.
