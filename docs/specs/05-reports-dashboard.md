# 05 – Report types, reports, dashboard

Folders: report folder `NFT_Demo_Reports` ("NFT Demo Reports"), dashboard folder
`NFT_Demo_Dashboards` ("NFT Demo Dashboards"). Share both with All Internal Users (view).

## 1. Custom report types

| API name | Label | Primary → related |
|---|---|---|
| `NFT_Orders` | NFT Orders | Order (all NFT fields + Account Name) |
| `NFT_Shipments_with_Order` | NFT Shipments with Order | `NFT_Shipment__c` (add Order fields via lookup) |
| `NFT_Inventory_Balances` | NFT Inventory Balances | `NFT_Inventory_Balance__c` (add Product fields via lookup) |
| `NFT_Sync_Logs` | NFT Sync Logs | `NFT_Sync_Log__c` (add Order fields via lookup) |

Deploy them as Deployed (not In Development).

## 2. Reports (all in `NFT_Demo_Reports`)

| API name | Report type | Filters | Grouping | Shows |
|---|---|---|---|---|
| `NFT_New_Orders_Today` | NFT Orders | Order Start Date = TODAY | Channel | Record count |
| `NFT_Awaiting_Shipment` | NFT Orders | Fulfillment Status = Received, Confirmed | Fulfillment Provider | Record count |
| `NFT_FBA_Orders_Last_30_Days` | NFT Orders | Fulfillment Provider = Amazon FBA; Order Start Date = LAST 30 DAYS | — | Record count |
| `NFT_Late_Shipments` | NFT Orders | Late Shipment = true | — | Count + list |
| `NFT_Low_Stock_SKUs` | NFT Inventory Balances | Low Stock = true | Location | Count + list |
| `NFT_Sync_Errors_24h` | NFT Sync Logs | Status = Failed; Logged At = LAST N DAYS:1 | System | Record count |
| `NFT_Orders_by_Channel_This_Month` | NFT Orders | Order Start Date = THIS MONTH | Channel | Count, sum Order Amount |
| `NFT_Shipments_by_Carrier_30_Days` | NFT Shipments with Order | Shipped At = LAST 30 DAYS | Carrier | Record count |
| `NFT_At_Risk_Orders` | NFT Orders | At Risk: Shipping = true OR Late Shipment = true | — | Order Number, Channel, Must Ship By, Fulfillment Status |
| `NFT_Customer_Orders_by_Channel` | NFT Orders | none (filtered by the page) | Channel | Record count |

## 3. Dashboard `NFT_Commerce_Operations`

Title "NFT Commerce Operations", folder `NFT_Demo_Dashboards`, running user = the
deploying user (placeholder `__RUNNING_USER__`, see CLAUDE.md §6). Lightning dashboard,
12-column grid.

Row 1 (the six KPI tiles of screen 1), each a Metric component 2 columns wide, 3 rows tall:

| Order | Title | Report | Colour rule |
|---|---|---|---|
| 1 | New orders today | `NFT_New_Orders_Today` | none |
| 2 | Awaiting shipment | `NFT_Awaiting_Shipment` | none |
| 3 | FBA orders · 30 days | `NFT_FBA_Orders_Last_30_Days` | none |
| 4 | Late shipments | `NFT_Late_Shipments` | red when > 0 |
| 5 | Low-stock SKUs | `NFT_Low_Stock_SKUs` | amber when > 0 |
| 6 | Sync errors | `NFT_Sync_Errors_24h` | red when > 0 |

Row 2 (below the fold, for the Dashboards tab): Donut `NFT_Orders_by_Channel_This_Month`
(4 cols), Pie `NFT_Shipments_by_Carrier_30_Days` (4 cols), Table `NFT_At_Risk_Orders` (4 cols).

On `NFT_Operations_Home` the Dashboard component height is set so only row 1 shows.
