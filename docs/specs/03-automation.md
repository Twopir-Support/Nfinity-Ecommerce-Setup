# 03 – Automation

12 flows, all deployed **Active**, all API names `NFT_…`, labels `NFT …`. No Apex.
Every flow that represents a system message writes one `NFT_Sync_Log__c` row through
the subflow `NFT_Write_Sync_Log`. Every screen flow shows a "(Simulated)" note on its
first screen and a success message on its last screen. Every DML element has a fault
path that shows the error on a screen (screen flows) or writes a Failed sync log
(record-triggered flows).

Build order: F0 first (others call it), then F1–F11.

## F0 `NFT_Write_Sync_Log` – autolaunched subflow

Inputs: `inOrderId` (Id, optional), `inRecordRef`, `inSystem`, `inEvent`, `inStatus`,
`inMessage` (text). Creates one `NFT_Sync_Log__c` with `NFT_Logged_At__c = NOW()`,
`NFT_Attempts__c = 1`, `NFT_External_Event_Id__c = inSystem & "-" & inRecordRef & "-" & TEXT(NOW())`
(+ a random 4-digit suffix from `MOD(VALUE(RIGHT(TEXT(NOW()),3)) * 7919, 10000)`).

## F1 `NFT_Simulate_Shopify_Order` – screen flow

Launched from: utility bar item "Simulate Shopify Order" and Account quick action
`Account.NFT_Simulate_New_Order` (passes `recordId`).

Screen 1 inputs: Account (lookup; prefilled from `recordId`), up to 3 lines (Product
lookup filtered to IsActive, Quantity 1–5), External Order ID (text, default
`"SHP-" & TEXT(10300 + <count of NFT Shopify orders>)`), checkbox "Resend an existing
order (shows duplicate protection)".

Logic:
1. If an Order exists with that `NFT_External_Order_Id__c` → call F0
   (Shopify, "Order received", Duplicate Blocked, "Same External Order ID received
   again. No new order or reservation created.") and show "Duplicate blocked" screen. Stop.
2. Create Order: AccountId, Pricebook2Id = standard price book, EffectiveDate = TODAY(),
   Status = Draft, `NFT_Channel__c` = Shopify, `NFT_Fulfillment_Provider__c` = ShipMonk,
   `NFT_Fulfillment_Status__c` = Received, `NFT_Received_At__c` = NOW(),
   `NFT_Must_Ship_By__c` = TODAY()+2, `NFT_Must_Deliver_By__c` = TODAY()+7,
   `NFT_Payment_Status__c` = Paid, `NFT_Shipping_Method__c` = IF(total > 150, "Free over $150", "Standard").
3. Create OrderItems with PricebookEntryId, Quantity, UnitPrice, `NFT_Line_No__c` 01…,
   `NFT_Line_Key__c` = External Order ID & "-" & Line No.
4. For each line: add Quantity to `NFT_Qty_Reserved__c` on the balance where
   Product = line product and Location = ShipMonk Warehouse; set `NFT_Last_Updated_At__c`.
5. Call F0 twice: (Shopify, "Order received", Success, "Order created. N units reserved at
   ShipMonk Warehouse.") and (Salesforce, "Stock reserved", Success, "N units reserved at ShipMonk Warehouse").
6. Final screen with a link to the new Order.

## F2 `NFT_Simulate_Amazon_Order` – screen flow

Same as F1 except: utility bar item "Simulate Amazon / FBA Order"; Account defaults to
"Amazon Customer (Masked)"; External Order ID default
`"11" & <random 1 digit> & "-" & <7 digits> & "-" & <7 digits>`; Channel = Amazon;
Provider = Amazon FBA; reserve at Location = Amazon FBA; F0 system = Amazon and
message "FBA order created. N units reserved at Amazon FBA."

## F3 `NFT_Simulate_3PL_Confirm` – screen flow, quick action `Order.NFT_ShipMonk_Confirm`

Button label "(Simulated) ShipMonk Confirm". Runs only if Fulfillment Status = Received
(otherwise screen: "Already confirmed"). Sets every line `NFT_Qty_Confirmed__c = Quantity`,
Order `NFT_Confirmed_At__c = NOW()`, Status = Confirmed. F0: (ShipMonk, "Fulfilment
request sent", Success) then (ShipMonk, "Order confirmed by 3PL", Success).
For Amazon FBA orders the confirm message system is "Amazon FBA".

## F4 `NFT_Simulate_Ship` – screen flow, quick action `Order.NFT_Ship`

Button "(Simulated) Ship". Screen: Carrier picklist (default UPS Ground; Amazon
Logistics for FBA), and per line "Units to ship" (default = Qty Confirmed − Qty Shipped,
max the same; also capped by the location's `NFT_Qty_On_Hand__c`).

Logic:
1. Create `NFT_Shipment__c`: Name = "SHP-" + next 5-digit number (highest existing
   shipment Name + 1), Order, Account (from Order), Provider (from Order), Carrier,
   Tracking Number (UPS: `"1Z84A7W00344" & 5 digits`; USPS: `"94055036993" & 8 digits`;
   FedEx: 12 digits; Amazon Logistics: `"TBA3188452" & 5 digits`), Status = In Transit,
   Units = total units, Contents = "N unit(s) · <product names>", Shipped At = NOW(),
   Expected Delivery = TODAY()+3, Sequence = "<n> of <n>" (recalculate all shipments on the order).
2. Add units to each line's `NFT_Qty_Shipped__c`.
3. On each balance: On Hand − units, Reserved − units, Last Updated At = NOW().
4. Order: First Shipped At = NOW() if blank; Status = Shipped if Units Shipped =
   Total Units, else Partially Shipped.
5. F0: (ShipStation, "Label and tracking", Success, "Shipment <name> created, <carrier>.").

## F5 `NFT_Simulate_Deliver` – screen flow, quick action `Order.NFT_Deliver`

Button "(Simulated) Deliver". Sets every shipment on the order with Status ≠ Delivered
to Delivered, Delivered At = NOW(). If Units Shipped = Total Units: Order Status =
Delivered, Delivered At = NOW(). F0: (ShipStation, "Shipment delivered", Success) per shipment.

## F6 `NFT_Simulate_Post_Invoice` – screen flow, quick action `Order.NFT_Post_Invoice`

Button "(Simulated) Post Invoice". Runs only if Units Shipped > Units Invoiced.
Creates `NFT_Invoice__c`: Name = "INV-" + next 5-digit number, Order, Account, Invoice Date = TODAY(), Amount = Σ over lines
of (Qty Shipped − Qty Invoiced) × UnitPrice, Status = Posted, Accounting Seed Ref =
`"AS-BIL-" & 5-digit sequence`. Sets each line `NFT_Qty_Invoiced__c = NFT_Qty_Shipped__c`.
Order Accounting Status = Posted. F0: (Accounting Seed, "Invoice post (simulated)", Success, "Invoice <name> posted.").

## F7 `NFT_Retry_Failed_Sync` – screen flow

Two entry points:
- Quick action `NFT_Sync_Log__c.NFT_Retry` (single record, button "Retry").
- Utility bar item "Retry Failed Syncs" (all records with Status = Failed).
For each Failed log: Attempts + 1, Status = Retried, Message = old message & " Retried
successfully (simulated)." Then call F0 with the same System, Event and Record Ref,
Status = Success, Message "Retry succeeded (simulated)." Final screen: "N syncs retried."

## F8 `NFT_Simulate_FBA_Inventory_Sync` – screen flow, quick action `Product2.NFT_FBA_Sync`

Button "(Simulated) Run FBA Inventory Sync". Sets the Amazon FBA balance for this
product: On Hand = On Hand (unchanged), Last Updated At = NOW(). F0: (Amazon FBA,
"Inventory sync", Success, "FBA quantities confirmed for <SKU>.").

## F9 `NFT_Balance_Update_Product_Totals` – record-triggered, after save

Object `NFT_Inventory_Balance__c`, create or update. Sums On Hand, Reserved, Available
(On Hand − Reserved) and Inbound over all balances of the same product and writes the
four `NFT_Total_…` fields on Product2.

## F10 `NFT_Order_Update_Customer_Totals` – record-triggered, after save

Object Order, runs on every create and update (no entry condition). For the order's
Account: Total Orders (count of orders), Open Orders (count where Is Open = true),
Lifetime Spend (sum of TotalAmount where Fulfillment Status ≠ Cancelled), Last Order
Date (max EffectiveDate). TotalAmount only changes when OrderItems are added, so F1 and
F2 end with one more update of the Order (re-set `NFT_Received_At__c`) to fire F10.

## F11 `NFT_Sync_Log_Update_Order` – record-triggered, after save

Object `NFT_Sync_Log__c`, create or update, when `NFT_Order__c` is not blank. Sets
Order `NFT_Failed_Sync_Count__c` = count of that order's logs with Status = Failed.

## Quick actions (type Flow) summary

| API name | Object | Label (button text) | Flow |
|---|---|---|---|
| `Order.NFT_ShipMonk_Confirm` | Order | (Simulated) ShipMonk Confirm | F3 |
| `Order.NFT_Ship` | Order | (Simulated) Ship | F4 |
| `Order.NFT_Deliver` | Order | (Simulated) Deliver | F5 |
| `Order.NFT_Post_Invoice` | Order | (Simulated) Post Invoice | F6 |
| `Account.NFT_Simulate_New_Order` | Account | Simulate New Order | F1 |
| `Product2.NFT_FBA_Sync` | Product2 | (Simulated) Run FBA Inventory Sync | F8 |
| `NFT_Sync_Log__c.NFT_Retry` | NFT Sync Log | Retry | F7 |

Dynamic action visibility on the Order page (specs/04):
- ShipMonk Confirm: Fulfillment Status = Received
- Ship: Fulfillment Status = Confirmed or Partially Shipped
- Deliver: Fulfillment Status = Shipped or Partially Shipped
- Post Invoice: `NFT_Can_Invoice__c` = true (specs/02 §4)
