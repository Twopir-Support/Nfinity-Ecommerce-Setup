# 02 – Data model

9 objects: 5 standard (Account, Contact, Product2, Order, OrderItem) and 4 custom.
Every new field and object below uses the `NFT_` API prefix. Field labels are plain
(see CLAUDE.md §1.1). All picklists are restricted. New fields on standard objects are never required at
field level, so existing processes in the org keep working.

## 1. Org settings

`Settings:Order` → `enableOrders = true`. Leave every other Order setting as it is.

## 2. Account (standard) – new fields

| Label | API name | Type | Details |
|---|---|---|---|
| Customer Key | `NFT_Customer_Key__c` | Text(30) (not required, so existing Account processes are unaffected) | External ID, Unique; e.g. SC-500231, AMZ-MASKED (used by data loads) |
| Customer Source | `NFT_Customer_Source__c` | Picklist | Shopify, Amazon |
| Shopify Customer ID | `NFT_Shopify_Customer_Id__c` | Text(30) | External ID, Unique |
| Amazon Buyer ID | `NFT_Amazon_Buyer_Id__c` | Text(30) | External ID, Unique |
| Rewards Tier | `NFT_Rewards_Tier__c` | Picklist | Bronze, Silver, Gold |
| Total Orders | `NFT_Total_Orders__c` | Number(8,0) | Set by flow `NFT_Order_Update_Customer_Totals` |
| Open Orders | `NFT_Open_Orders__c` | Number(8,0) | Set by the same flow |
| Lifetime Spend | `NFT_Lifetime_Spend__c` | Currency(12,2) | Set by the same flow (excludes Cancelled) |
| Last Order Date | `NFT_Last_Order_Date__c` | Date | Set by the same flow |

Contact: no new fields (uses FirstName, LastName, Email, Phone).

## 3. Product2 (standard) – new fields

`ProductCode` holds the SKU. `Family` picklist gets values Shoes, Backpacks.

| Label | API name | Type | Details |
|---|---|---|---|
| SKU (key) | `NFT_SKU__c` | Text(30) | External ID, Unique; same value as ProductCode |
| Style | `NFT_Style__c` | Picklist | Apex, Glide, Titan, Pulse, Nova, Shimmer |
| Colour | `NFT_Colour__c` | Picklist | White, Black, Teal, Red, Blue, Purple |
| Size | `NFT_Size__c` | Text(10) | 6, 7, 8, One Size |
| Total On Hand | `NFT_Total_On_Hand__c` | Number(8,0) | Set by flow `NFT_Balance_Update_Product_Totals` |
| Total Reserved | `NFT_Total_Reserved__c` | Number(8,0) | Same flow |
| Total Available | `NFT_Total_Available__c` | Number(8,0) | Same flow |
| Total Inbound | `NFT_Total_Inbound__c` | Number(8,0) | Same flow |

## 4. Order (standard) – new fields

Standard fields used as-is: OrderNumber, AccountId, BillToContactId, EffectiveDate,
Status (always `Draft`), TotalAmount, Pricebook2Id, ShippingAddress.

| Label | API name | Type | Details |
|---|---|---|---|
| Channel | `NFT_Channel__c` | Picklist (required on NFT layout only) | Shopify, Amazon |
| External Order ID | `NFT_External_Order_Id__c` | Text(40) (required on NFT layout only) | External ID, Unique, case-insensitive |
| Fulfillment Provider | `NFT_Fulfillment_Provider__c` | Picklist (required on NFT layout only) | ShipMonk, Amazon FBA |
| Fulfillment Status | `NFT_Fulfillment_Status__c` | Picklist (required on NFT layout only) | Received, Confirmed, Partially Shipped, Shipped, Delivered, Cancelled (default Received) |
| Payment Status | `NFT_Payment_Status__c` | Picklist | Paid, Partially Refunded, Refunded |
| Shipping Method | `NFT_Shipping_Method__c` | Picklist | Standard, Expedited, Free over $150 |
| Received At | `NFT_Received_At__c` | Date/Time | |
| Confirmed At | `NFT_Confirmed_At__c` | Date/Time | |
| First Shipped At | `NFT_First_Shipped_At__c` | Date/Time | |
| Delivered At | `NFT_Delivered_At__c` | Date/Time | |
| Must Ship By | `NFT_Must_Ship_By__c` | Date | |
| Must Deliver By | `NFT_Must_Deliver_By__c` | Date | |
| Accounting Status (Simulated) | `NFT_Accounting_Status__c` | Picklist | Not Posted, Posted, Reconciled (default Not Posted) |
| Failed Sync Count | `NFT_Failed_Sync_Count__c` | Number(4,0), default 0 | Set by flow `NFT_Sync_Log_Update_Order` |
| Total Units | `NFT_Total_Units__c` | Roll-up SUM | OrderItem.Quantity |
| Units Confirmed | `NFT_Units_Confirmed__c` | Roll-up SUM | OrderItem.`NFT_Qty_Confirmed__c` |
| Units Shipped | `NFT_Units_Shipped__c` | Roll-up SUM | OrderItem.`NFT_Qty_Shipped__c` |
| Units Invoiced | `NFT_Units_Invoiced__c` | Roll-up SUM | OrderItem.`NFT_Qty_Invoiced__c` |
| Line Count | `NFT_Line_Count__c` | Roll-up COUNT | OrderItem |
| % Confirmed | `NFT_Pct_Confirmed__c` | Formula Percent(3,0) | `IF(NFT_Total_Units__c = 0, 0, NFT_Units_Confirmed__c / NFT_Total_Units__c)` |
| % Shipped | `NFT_Pct_Shipped__c` | Formula Percent(3,0) | `IF(NFT_Total_Units__c = 0, 0, NFT_Units_Shipped__c / NFT_Total_Units__c)` |
| % Invoiced | `NFT_Pct_Invoiced__c` | Formula Percent(3,0) | `IF(NFT_Total_Units__c = 0, 0, NFT_Units_Invoiced__c / NFT_Total_Units__c)` |
| Is Open | `NFT_Is_Open__c` | Formula Checkbox | `NOT(OR(ISPICKVAL(NFT_Fulfillment_Status__c,"Delivered"), ISPICKVAL(NFT_Fulfillment_Status__c,"Cancelled")))` |
| Needs Shipping | `NFT_Needs_Shipping__c` | Formula Checkbox | `OR(ISPICKVAL(NFT_Fulfillment_Status__c,"Received"), ISPICKVAL(NFT_Fulfillment_Status__c,"Confirmed"), ISPICKVAL(NFT_Fulfillment_Status__c,"Partially Shipped"))` |
| At Risk: Shipping | `NFT_At_Risk_Shipping__c` | Formula Checkbox | `AND(NFT_Needs_Shipping__c, NFT_Must_Ship_By__c = TODAY())` |
| Late Shipment | `NFT_Late_Shipment__c` | Formula Checkbox | `AND(NFT_Needs_Shipping__c, NFT_Must_Ship_By__c < TODAY())` |
| Alert | `NFT_Alert__c` | Formula Text | `IF(NFT_Late_Shipment__c, "Late", IF(NFT_At_Risk_Shipping__c, "At risk", ""))` |
| Can Invoice | `NFT_Can_Invoice__c` | Formula Checkbox | `NFT_Units_Shipped__c > NFT_Units_Invoiced__c` |
| Units Shipped Label | `NFT_Units_Shipped_Label__c` | Formula Text | `TEXT(NFT_Units_Shipped__c) & " / " & TEXT(NFT_Total_Units__c)` |

Note: "Is Open" = not Delivered and not Cancelled (the home screen's Open orders tab).
"Needs Shipping" = Received, Confirmed or Partially Shipped (drives the alerts).

Field history tracking on Order: `NFT_Fulfillment_Status__c`, `NFT_Accounting_Status__c`.

## 5. OrderItem (standard) – new fields

| Label | API name | Type | Details |
|---|---|---|---|
| Line No | `NFT_Line_No__c` | Text(4) | 01, 02, … |
| Line Key | `NFT_Line_Key__c` | Text(60) | External ID, Unique; `<External Order ID>-<Line No>` |
| Qty Confirmed | `NFT_Qty_Confirmed__c` | Number(6,0), default 0 | |
| Qty Shipped | `NFT_Qty_Shipped__c` | Number(6,0), default 0 | |
| Qty Invoiced | `NFT_Qty_Invoiced__c` | Number(6,0), default 0 | |
| Line Status | `NFT_Line_Status__c` | Formula Text | `IF(NFT_Qty_Shipped__c >= Quantity, "Shipped", IF(NFT_Qty_Shipped__c > 0, "Partially Shipped", IF(NFT_Qty_Confirmed__c > 0, "Confirmed", "Pending")))` |
| Short Shipped | `NFT_Short_Shipped__c` | Formula Checkbox | `AND(NFT_Qty_Shipped__c > 0, NFT_Qty_Shipped__c < Quantity)` |

## 6. NFT Shipment (`NFT_Shipment__c`) – custom object

Label `NFT Shipment`, plural `NFT Shipments`. Name: Text(20), e.g. `SHP-00451` (set by
flow F4 as the next number; set by the data load for demo records).
Enable Reports, Activities, Track Field History, Search. Sharing: Read/Write. Tab: yes.

| Label | API name | Type | Details |
|---|---|---|---|
| Order | `NFT_Order__c` | Lookup(Order), required, delete restricted | Related list label "Shipments" |
| Account | `NFT_Account__c` | Lookup(Account) | Copied from Order by flow; related list "Shipments" |
| Provider | `NFT_Provider__c` | Picklist | ShipMonk, Amazon FBA |
| Carrier | `NFT_Carrier__c` | Picklist | UPS Ground, USPS Priority, FedEx Ground, DHL eCommerce, Amazon Logistics |
| Tracking Number | `NFT_Tracking_Number__c` | Text(40) | External ID, Unique |
| Status | `NFT_Status__c` | Picklist | Label Created, In Transit, Out for Delivery, Delivered, Exception (track history) |
| Sequence | `NFT_Sequence__c` | Text(10) | e.g. "1 of 2" |
| Units | `NFT_Units__c` | Number(6,0) | |
| Contents | `NFT_Contents__c` | Text(120) | e.g. "1 unit · Shimmer Backpack – Teal" |
| Shipped At | `NFT_Shipped_At__c` | Date/Time | |
| Expected Delivery | `NFT_Expected_Delivery__c` | Date | |
| Delivered At | `NFT_Delivered_At__c` | Date/Time | |

## 7. NFT Invoice (`NFT_Invoice__c`) – custom object

Label `NFT Invoice (Simulated)`, plural `NFT Invoices (Simulated)`. Name: Text(20), e.g.
`INV-00318` (set by flow F6 as the next number; set by the data load for demo records). Enable Reports, Search. Tab: yes.

| Label | API name | Type | Details |
|---|---|---|---|
| Order | `NFT_Order__c` | Lookup(Order), required | Related list "Invoices" |
| Account | `NFT_Account__c` | Lookup(Account) | Copied from Order by flow; related list "Invoices" |
| Invoice Date | `NFT_Invoice_Date__c` | Date | |
| Amount | `NFT_Amount__c` | Currency(12,2) | |
| Status | `NFT_Status__c` | Picklist | Draft, Posted, Paid |
| Accounting Seed Ref | `NFT_Accounting_Seed_Ref__c` | Text(30) | External ID, Unique; e.g. AS-BIL-00087 (dummy) |

## 8. NFT Inventory Balance (`NFT_Inventory_Balance__c`) – custom object

Label `NFT Inventory Balance`. Name: Text(80), value `<SKU> – <Location>`.
Enable Reports, Search. Tab: yes.

| Label | API name | Type | Details |
|---|---|---|---|
| Product | `NFT_Product__c` | Lookup(Product2), required | Related list "Inventory Balances" |
| Location | `NFT_Location__c` | Picklist, required | ShipMonk Warehouse, Amazon FBA |
| Location Type | `NFT_Location_Type__c` | Picklist | 3PL Warehouse, Marketplace Fulfilment |
| Unique Key | `NFT_Unique_Key__c` | Text(80) | External ID, Unique; `<ProductCode>-<SM or FBA>` |
| Qty On Hand | `NFT_Qty_On_Hand__c` | Number(8,0), default 0 | |
| Qty Reserved | `NFT_Qty_Reserved__c` | Number(8,0), default 0 | |
| Qty Inbound | `NFT_Qty_Inbound__c` | Number(8,0), default 0 | |
| Qty Available | `NFT_Qty_Available__c` | Formula Number | `NFT_Qty_On_Hand__c - NFT_Qty_Reserved__c` |
| Reorder Point | `NFT_Reorder_Point__c` | Number(8,0) | |
| Low Stock | `NFT_Low_Stock__c` | Formula Checkbox | `NFT_Qty_Available__c <= NFT_Reorder_Point__c` |
| Stock Flag | `NFT_Stock_Flag__c` | Formula Text | `IF(NFT_Low_Stock__c, "Low stock", "OK")` |
| Last Updated At | `NFT_Last_Updated_At__c` | Date/Time | |

## 9. NFT Sync Log (`NFT_Sync_Log__c`) – custom object

Label `NFT Sync Log`. Name: Auto Number `LOG-{000000}`. Enable Reports, Search. Tab: yes.

| Label | API name | Type | Details |
|---|---|---|---|
| Order | `NFT_Order__c` | Lookup(Order) | Optional; related list "Order Timeline" |
| Record Reference | `NFT_Record_Ref__c` | Text(60) | External Order ID or SKU shown in lists |
| System | `NFT_System__c` | Picklist | Shopify, Amazon, Amazon FBA, ShipMonk, ShipStation, Accounting Seed, Salesforce |
| Event | `NFT_Event__c` | Text(80) | e.g. "Order received", "Tracking update" |
| Status | `NFT_Status__c` | Picklist | Success, Failed, Duplicate Blocked, Retried |
| Message | `NFT_Message__c` | Text Area(255) | |
| Logged At | `NFT_Logged_At__c` | Date/Time, required | |
| Attempts | `NFT_Attempts__c` | Number(3,0), default 1 | |
| External Event ID | `NFT_External_Event_Id__c` | Text(80) | External ID, Unique |
| Can Retry | `NFT_Can_Retry__c` | Formula Checkbox | `ISPICKVAL(NFT_Status__c, "Failed")` |

## 10. Relationships summary

- Account 1 → many Contact, Order, `NFT_Shipment__c` (via `NFT_Account__c`), `NFT_Invoice__c`
- Order 1 → many OrderItem, `NFT_Shipment__c`, `NFT_Invoice__c`, `NFT_Sync_Log__c`
- Product2 1 → many OrderItem, `NFT_Inventory_Balance__c`

## 11. Permission set `NFT_Commerce_Hub_User`

Label `NFT Commerce Hub User`. Grants:
- Read/Create/Edit on Account, Contact, Product2, Order, OrderItem, Pricebook2 (read), PricebookEntry (read).
- Read/Create/Edit/Delete on all four NFT objects; View All on them.
- Read/Edit on every NFT field (Read only on formula and roll-up fields).
- Tab visibility: Visible for the 4 NFT tabs and `NFT_Operations_Home`.
- App visibility: `NFT_Commerce_Integration_Hub`.
- Run Flows (user permission) if the org requires it.
Assign it to the running user after deploy.
