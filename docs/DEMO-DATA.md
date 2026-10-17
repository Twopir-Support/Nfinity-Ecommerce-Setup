# NFT demo data – what is loaded and what the dashboard shows

The demo data lives in the `NFT_DemoData_*` static resources and is loaded by `NFT_DemoDataLoader`.
Every date is an offset from the **day you load it**, so the "Today", "24h" and "30 days" numbers
are only right on the load day. **Run the refresh on the morning of a client demo.**

## One shot: insert all demo data

```
./scripts/import-demo-data.ps1 -Org nft-demo     # Windows
./scripts/import-demo-data.sh nft-demo           # macOS / Linux / Git Bash
```

Assigns `NFT_Commerce_Hub_Access`, then: empty org → re-dates and tree-imports `data/` (2,921 records) and
recalculates totals; org with demo data → clears demo transactions and reloads them with the Apex upsert
loader. Ends with the CHECK lines.

## JSON data files (`data/`)

`data/` holds the demo data as `sf data import tree` files, one per object (split into files of up to
200 records, the Tree API limit), plus the plan `data/nft-demo-data-plan.json` that imports them in order
and links the references (Product → Account → Contact → Inventory Balance → Order → Order Product →
Shipment → Invoice → Sync Log).

`scripts/deploy.ps1` / `deploy.sh` regenerate the files dated from today and import them right after the
core metadata, so **one deploy command deploys and inserts the data**. To do it by hand:

```bash
node scripts/build-demo-data.js                     # re-date to today (or pass a demo day: 2026-10-21)
sf data import tree --plan data/nft-demo-data-plan.json --target-org nft-demo
sf apex run --file scripts/apex/load/7-finish.apex --target-org nft-demo   # product stock totals
```

Notes:
- The tree import **inserts**, so use it on an org without NFT demo data. The deploy script checks this and
  uses the Apex upsert loader instead when demo orders already exist or the import fails part-way.
- Orders and order lines carry no price book Id (it differs per org). `NFT_OrderTrigger` and
  `NFT_OrderItemTrigger` fill in the Standard Price Book and create the product's standard price from
  the line price.
- The user running the import needs edit access to the NFT fields (profile field-level security).
  The Apex loader runs in system mode and does not.

## Load / refresh

| When | Windows | macOS / Linux / Git Bash |
|---|---|---|
| First load (metadata already deployed) | `./scripts/load-demo-data.ps1 -Org nft-demo` | `./scripts/load-demo-data.sh nft-demo` |
| Demo day (re-date everything to today) | `./scripts/load-demo-data.ps1 -Org nft-demo -Refresh` | `./scripts/load-demo-data.sh nft-demo --refresh` |

The refresh clears demo orders, order lines, shipments, invoices and sync logs, then reloads them.
Products, customers and stock are upserted back to the demo values (no duplicates). The script
ends with the `verify.apex` checks; every CHECK line should read PASS.

## Records per object

| Object | Records | Mix |
|---|---|---|
| Product (`Product2`) | 34 | 30 shoes, 4 backpacks, all priced in the Standard Price Book |
| Account + Contact | 101 + 101 | 100 Shopify customers, 1 Amazon buyer; Bronze 62 / Silver 24 / Gold 14 |
| `NFT_Inventory_Balance__c` | 68 | Each SKU at ShipMonk Warehouse and Amazon FBA; 6 below reorder point |
| Order | 278 | Shopify 184 (ShipMonk), Amazon 94 (Amazon FBA); last 88 days, 18 placed today |
| Order Product (`OrderItem`) | 400 | Confirmed / shipped / invoiced quantities filled in |
| `NFT_Shipment__c` | 242 | Delivered 214, In Transit 23, Label Created 4, Out for Delivery 1 |
| `NFT_Invoice__c` | 213 | Paid 172, Posted 41 |
| `NFT_Sync_Log__c` | 1,484 | 7 systems; 3 Failed today, 1 Duplicate Blocked |

Order fulfilment status: Delivered 213, Shipped 23, Received 14, Confirmed 13, Cancelled 10,
Partially Shipped 5. Standard Order Status stays `Draft`.

## Dashboard `NFT_Commerce_Operations` on the load day

| Component | Report | Shows |
|---|---|---|
| New Orders Today | `NFT_New_Orders_Today` | 18 (Shopify 13, Amazon 5) |
| Awaiting Shipment | `NFT_Awaiting_Shipment` | 27 (ShipMonk 23, Amazon FBA 4) |
| FBA Orders – 30 days | `NFT_FBA_Orders_Last_30_Days` | 74 |
| Late Shipments | `NFT_Late_Shipments` | 4 |
| Low-Stock SKUs | `NFT_Low_Stock_SKUs` | 6 |
| Sync Errors – 24h | `NFT_Sync_Errors_24h` | 3 |
| Orders by Channel – this month (donut) | `NFT_Orders_by_Channel_This_Month` | Shopify / Amazon split. Uses calendar month, so it is small in the first days of a month. |
| Shipments by Carrier – 30 days (pie) | `NFT_Shipments_by_Carrier_30_Days` | Amazon Logistics, UPS Ground, USPS Priority, FedEx Ground, DHL eCommerce |

## Records to open in the demo

| Record | Why |
|---|---|
| Order `SHP-10234` | Partially Shipped, $369.97, 10-step order timeline, 1 failed sync to retry |
| Account with key `SC-500231` (Madison) | 6 orders, 2 open, $1,114.91 lifetime spend |
| Product `APEX-WHT-07` | Low stock at ShipMonk: 48 on hand, 39 available |
