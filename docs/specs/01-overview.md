# 01 – Overview

## What we are building

A Salesforce Lightning app, **Commerce Integration Hub** (`NFT_Commerce_Integration_Hub`),
for a direct-to-consumer brand that sells on Shopify and Amazon, ships through a 3PL
(ShipMonk) and Amazon FBA, prints labels in ShipStation and keeps its books in
Accounting Seed. Nothing is connected live: every integration is simulated by screen
flows, and the org is loaded with dummy data.

## The four screens (see `reference/ui-reference.html`)

| # | Screen | Salesforce page | Spec |
|---|---|---|---|
| 1 | Operations home | `NFT_Operations_Home` app page | 04 §4.1, 05 |
| 2 | Order 360 | `NFT_Order_Record_Page` | 04 §4.2, §5 |
| 3 | Product stock | `NFT_Product_Record_Page` | 04 §4.3 |
| 4 | Customer | `NFT_Account_Record_Page` | 04 §4.4 |

## Component count

| Type | Count | Names |
|---|---|---|
| Custom objects | 4 | `NFT_Shipment__c`, `NFT_Invoice__c`, `NFT_Inventory_Balance__c`, `NFT_Sync_Log__c` |
| New fields on standard objects | ~50 | all `NFT_…` (Account, Product2, Order, OrderItem) |
| Flows | 12 | F0–F11 in specs/03 |
| Quick actions | 7 | specs/03 |
| LWC | 1 | `nftOrderLineStatus` |
| Apex | 0 | — |
| Lightning pages | 5 | 4 pages + utility bar |
| Layouts / compact layouts | 7 / 7 | specs/04 §1 |
| List views | 9 | specs/04 §3 |
| Report types / reports / dashboards | 4 / 10 / 1 | specs/05 |
| App / permission set / path | 1 / 1 / 1 | — |

## Design decisions the build must keep

- Order is the hub. Standard Order Status stays Draft; `NFT_Fulfillment_Status__c` is the lifecycle.
- Stock is held per SKU per location in `NFT_Inventory_Balance__c`; Shopify orders reserve
  at ShipMonk Warehouse, Amazon orders at Amazon FBA.
- Every simulated system message is one `NFT_Sync_Log__c` row; it is both the order
  timeline and the error log.
- Duplicate protection comes from the unique `NFT_External_Order_Id__c`.
- Invoices are simulated (`NFT_Invoice__c`); no Accounting Seed objects are touched.
