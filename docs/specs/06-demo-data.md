# 06 – Demo data

`D` = the load day (or `DEMO_TODAY` in CLAUDE.md §9). Every date below is relative to D,
so the demo always looks current. "D−2 09:12" means two days before D at 09:12 in the
running user's time zone.

## 1. How to load

Write `scripts/generate_data.py` (generates CSVs in `data/`) and
`scripts/load_data.sh` (loads them with the `sf` CLI). Loads are **upserts on the
external keys** below, so running the load twice never duplicates anything.

| Step | Object | Upsert key | Parent reference in CSV |
|---|---|---|---|
| 1 | Product2 | `NFT_SKU__c` | — |
| 2 | PricebookEntry | — (script: query standard price book, skip existing) | Product2 via `NFT_SKU__c` lookup in script |
| 3 | Account | `NFT_Customer_Key__c` | — |
| 4 | Contact | Email | `Account.NFT_Customer_Key__c` |
| 5 | `NFT_Inventory_Balance__c` | `NFT_Unique_Key__c` | `NFT_Product__r.NFT_SKU__c` |
| 6 | Order | `NFT_External_Order_Id__c` | `Account.NFT_Customer_Key__c`; Pricebook2Id from script |
| 7 | OrderItem | `NFT_Line_Key__c` | `Order.NFT_External_Order_Id__c`; PricebookEntryId from a ProductCode→Id map the script queries |
| 8 | `NFT_Shipment__c` | `NFT_Tracking_Number__c` | `NFT_Order__r.NFT_External_Order_Id__c`, `NFT_Account__r.NFT_Customer_Key__c` |
| 9 | `NFT_Invoice__c` | `NFT_Accounting_Seed_Ref__c` | same as shipments |
| 10 | `NFT_Sync_Log__c` | `NFT_External_Event_Id__c` | `NFT_Order__r.NFT_External_Order_Id__c` (blank when no order) |

Use `sf data upsert bulk --external-id <key> --wait 10`. Orders stay Status = Draft,
EffectiveDate = the order date, ShippingAddress from the customer.
Record-triggered flows F9–F11 stay active during the load; they fill Account and
Product totals and the order's failed-sync count. After the load, run step 6 again
(a no-change upsert) so F10 sees final order totals.

Order Number is a standard auto number and will not match the preview; the External
Order ID is what must match.

## 2. Products (34)

Shoes: 5 styles × 2 colours (White, Black) × 3 sizes (6, 7, 8) = 30. Family = Shoes.

| Style | Code | Name pattern | Price |
|---|---|---|---|
| Apex | APEX | Apex Cheer Shoe – <Colour> – <Size> | $129.99 |
| Glide | GLID | Glide Cheer Shoe – <Colour> – <Size> | $144.99 |
| Titan | TITN | Titan Mid-Top – <Colour> – <Size> | $149.99 |
| Pulse | PULS | Pulse Cheer Shoe – <Colour> – <Size> | $99.99 |
| Nova | NOVA | Nova Cheer Shoe – <Colour> – <Size> | $139.99 |

SKU = `<Code>-<WHT|BLK>-0<Size>` (e.g. APEX-WHT-07). ProductCode = `NFT_SKU__c` = SKU.

Backpacks: Shimmer Backpack – Teal / Red / Blue / Purple, SKUs SHBP-TEA-OS, SHBP-RED-OS,
SHBP-BLU-OS, SHBP-PUR-OS, Family = Backpacks, Size = One Size, $109.99.

All IsActive = true, each with a standard price book entry at its price.

## 3. Inventory balances (68 = 34 SKUs × 2 locations)

Key `<SKU>-SM` (ShipMonk Warehouse, 3PL Warehouse) and `<SKU>-FBA` (Amazon FBA,
Marketplace Fulfilment). Name `<SKU> – <Location>`.

Fixed rows (must match the preview):

| Key | On hand | Reserved | Inbound | Reorder point |
|---|---|---|---|---|
| APEX-WHT-07-SM | 6 | 6 | 48 | 10 |
| APEX-WHT-07-FBA | 42 | 3 | 0 | 15 |
| GLID-BLK-08-FBA | 9 | 2 | 0 | 12 |
| TITN-WHT-06-SM | 14 | 5 | 24 | 10 |
| SHBP-TEA-OS-SM | 31 | 4 | 0 | 15 |
| PULS-WHT-07-SM | 120 | 11 | 0 | 25 |
| NOVA-BLK-06-SM | 11 | 3 | 30 | 10 |
| APEX-BLK-08-FBA | 8 | 1 | 0 | 10 |
| SHBP-PUR-OS-FBA | 7 | 0 | 12 | 8 |

Exactly these 6 are low stock (Available ≤ Reorder): APEX-WHT-07-SM, GLID-BLK-08-FBA,
TITN-WHT-06-SM, NOVA-BLK-06-SM, APEX-BLK-08-FBA, SHBP-PUR-OS-FBA.
All other rows: ShipMonk on hand 40–300, FBA on hand 20–150, reserved 0–8, inbound 0,
reorder point 10–25, chosen so Available > Reorder point. Last Updated At = D 07:45 for
FBA rows, D 09:20 for ShipMonk rows.

## 4. Customers (Accounts + one Contact each)

Fixed accounts:

| Customer key | Name | Source | Tier | Contact email | Phone | Ship-to |
|---|---|---|---|---|---|---|
| SC-500231 | Madison Carter | Shopify | Gold | madison.carter@example.com | (214) 555-0187 | 1420 Maple Ridge Dr, Plano, TX 75024, US |
| SC-500244 | Ava Thompson | Shopify | Silver | ava.thompson@example.com | (512) 555-0142 | 88 Cedar Bend, Austin, TX 78704, US |
| SC-500198 | Chloe Ramirez | Shopify | Silver | chloe.ramirez@example.com | (602) 555-0119 | 310 Palm Ct, Tempe, AZ 85281, US |
| SC-500207 | Lily Nguyen | Shopify | Bronze | lily.nguyen@example.com | (404) 555-0163 | 9 Willow Way, Atlanta, GA 30309, US |
| SC-500252 | Harper Wilson | Shopify | Bronze | harper.wilson@example.com | (615) 555-0175 | 47 Oak Hollow, Nashville, TN 37205, US |
| AMZ-MASKED | Amazon Customer (Masked) | Amazon | — | amazon.masked@example.com | — | — |

Plus 95 more Shopify accounts, keys SC-500300 … SC-500394, realistic first/last names,
emails `first.last@example.com`, US addresses, tiers Bronze 60% / Silver 30% / Gold 10%.
Use only `example.com` emails and `555-01xx` phone numbers.

## 5. Orders

### 5.1 Fixed orders (copy exactly)

| External Order ID | Customer | Order date | Status | Must ship by | Lines (SKU × qty) | Amount |
|---|---|---|---|---|---|---|
| SHP-10234 | SC-500231 | D−2 09:12 | Partially Shipped | D | APEX-WHT-07 × 2; SHBP-TEA-OS × 1 | $369.97 |
| SHP-10241 | SC-500231 | D 09:20 | Received | D+2 | TITN-WHT-07 × 1 | $149.99 |
| SHP-10187 | SC-500231 | D−19 | Delivered | D−17 | GLID-WHT-07 × 1 | $144.99 |
| SHP-10102 | SC-500231 | D−48 | Delivered | D−46 | SHBP-RED-OS × 1 | $109.99 |
| SHP-10055 | SC-500231 | D−66 | Delivered | D−64 | PULS-BLK-07 × 2 | $199.98 |
| SHP-10012 | SC-500231 | D−88 | Delivered | D−86 | NOVA-WHT-07 × 1 | $139.99 |
| SHP-10228 | SC-500198 | D−3 | Confirmed | D−1 | GLID-BLK-07 × 1 | $144.99 |
| SHP-10236 | SC-500252 | D−2 | Confirmed | D | TITN-BLK-07 × 1 | $149.99 |
| SHP-10239 | SC-500244 | D 08:40 | Received | D+1 | APEX-WHT-07 × 2 | $259.98 |
| SHP-10237 | SC-500207 | D−2 | Shipped | D | APEX-BLK-07 × 1; SHBP-PUR-OS × 1 | $239.98 |
| SHP-10221 | SC-500207 | D−5 | Delivered | D−3 | APEX-WHT-08 × 1; SHBP-BLU-OS × 1 | $239.98 |
| SHP-10238 | SC-500252 | D−1 | Partially Shipped | D+1 | PULS-WHT-07 × 2 | $199.98 |
| SHP-10229 | SC-500198 | D−4 | Delivered | D−2 | NOVA-BLK-07 × 2 | $279.98 |
| 112-4839201-7735102 | AMZ-MASKED | D−2 | Shipped | D | APEX-WHT-07 × 1 | $129.99 |
| 113-2209481-5530217 | AMZ-MASKED | D 09:05 | Received | D+1 | SHBP-BLU-OS × 2 | $219.98 |

Remaining fields for fixed orders:
- Channel/Provider: SHP-… = Shopify/ShipMonk; 11x-… = Amazon/Amazon FBA.
- Payment Status = Paid; Shipping Method = "Free over $150" when amount > 150, else Standard.
- Must Deliver By = Must Ship By + 5. Received At = order date and time (09:00 if none given).
- Confirmed At = order date + 2 h for every status from Confirmed on.
- SHP-10234: Confirmed At D−2 11:05, First Shipped At D−2 16:10, Accounting Status Posted.
- Line quantities: Confirmed = Quantity for every status from Confirmed on. Shipped and
  Invoiced: Delivered and Shipped orders fully shipped; Delivered fully invoiced;
  SHP-10234 line 01: shipped 1, invoiced 0; line 02: shipped 1, invoiced 1;
  SHP-10238: shipped 1 of 2, invoiced 0; SHP-10237 and 112-4839201-7735102 invoiced 0.
- Delivered At = Must Ship By + 2 days for Delivered orders.

Customer totals this produces (check after load): Madison 6 orders, 2 open, $1,114.91.
Lily 2 orders, 1 open, $479.96. Ava, Chloe, Harper: whatever the generated orders add up to.

### 5.2 Generated orders

About 280 more orders over D−60 … D, so the total is about 300:
- 70% Shopify / ShipMonk across the 100 Shopify accounts (fixed accounts may get more
  orders, but not Madison and not Lily); 30% Amazon / FBA on AMZ-MASKED.
- External IDs: Shopify `SHP-1xxxx` not used above; Amazon `11d-ddddddd-ddddddd`, unique.
- 1–3 lines each, quantities 1–2, random SKUs.
- Older than D−5: 95% Delivered, 5% Cancelled. D−5 … D: a mix of every status.
- Must Ship By = order date + 2 days.

### 5.3 KPI targets on day D (the generator must hit these exactly, counting fixed orders)

| KPI | Definition | Target |
|---|---|---|
| New orders today | Order date = D | 18 (Shopify 13, Amazon 5) |
| Awaiting shipment | Status Received or Confirmed | 27 |
| FBA orders · 30 days | Provider Amazon FBA, order date D−30 … D | 74 |
| Late shipments | Late Shipment = true | 4 (SHP-10228 + 3 generated) |
| Low-stock SKUs | Low Stock = true | 6 |
| Sync errors | Failed logs with Logged At in the last day | 3 |

The generator asserts these counts on its own output before writing CSVs.

## 6. Shipments

Fixed (copy exactly):

| Name | Order | Provider | Carrier | Tracking number | Seq | Units | Contents | Status | Shipped at | Expected | Delivered at |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SHP-00451 | SHP-10234 | ShipMonk | USPS Priority | 9405503699300451221 | 1 of 2 | 1 | 1 unit · Shimmer Backpack – Teal | Delivered | D−2 16:10 | D | D 10:15 |
| SHP-00463 | SHP-10234 | ShipMonk | UPS Ground | 1Z84A7W0034410662 | 2 of 2 | 1 | 1 unit · Apex Cheer Shoe – White – 7 | In Transit | D−1 14:20 | D+2 | — |
| SHP-00466 | 112-4839201-7735102 | Amazon FBA | Amazon Logistics | TBA318845220019 | 1 of 1 | 1 | 1 unit · Apex Cheer Shoe – White – 7 | Out for Delivery | D−1 | D+1 | — |
| SHP-00465 | SHP-10237 | ShipMonk | USPS Priority | 9405503699300465221 | 1 of 1 | 2 | 2 units · Apex Cheer Shoe – Black – 7, Shimmer Backpack – Purple | In Transit | D−1 | D+1 | — |
| SHP-00449 | SHP-10221 | ShipMonk | FedEx Ground | 784512093318 | 1 of 1 | 2 | 2 units · Apex Cheer Shoe – White – 8, Shimmer Backpack – Blue | Delivered | D−3 | D−1 | D−1 |
| SHP-00467 | SHP-10238 | ShipMonk | UPS Ground | 1Z84A7W0034410689 | 1 of 1 | 1 | 1 unit · Pulse Cheer Shoe – White – 7 | Label Created | D | D+3 | — |
| SHP-00398 | SHP-10187 | ShipMonk | UPS Ground | 1Z84A7W0034409871 | 1 of 1 | 1 | 1 unit · Glide Cheer Shoe – White – 7 | Delivered | D−18 | D−15 | D−15 |
| SHP-00311 | SHP-10102 | ShipMonk | USPS Priority | 9405503699300311904 | 1 of 1 | 1 | 1 unit · Shimmer Backpack – Red | Delivered | D−47 | D−44 | D−44 |
| SHP-00262 | SHP-10055 | ShipMonk | FedEx Ground | 784512077105 | 1 of 1 | 2 | 2 units · Pulse Cheer Shoe – Black – 7 | Delivered | D−65 | D−63 | D−63 |
| SHP-00205 | SHP-10012 | ShipMonk | UPS Ground | 1Z84A7W0034406623 | 1 of 1 | 1 | 1 unit · Nova Cheer Shoe – White – 7 | Delivered | D−87 | D−85 | D−85 |
| SHP-00452 | SHP-10229 | ShipMonk | UPS Ground | 1Z84A7W0034410511 | 1 of 1 | 2 | 2 units · Nova Cheer Shoe – Black – 7 | Delivered | D−3 | D−2 | D−2 |

Generated orders get one shipment each when Partially Shipped, Shipped or Delivered
(about 10% of delivered ones get 2). Names SHP-00100 … upward, skipping the fixed
names. Carrier mix: UPS 40%, USPS 30%, FedEx 15%, DHL 5%; Amazon Logistics for all FBA.

## 7. Invoices

Fixed: INV-00318 / SHP-10234 / D−2 / $109.99 / Posted / AS-BIL-00087; INV-00284 /
SHP-10187 / D−18 / $144.99 / Paid / AS-BIL-00061; INV-00221 / SHP-10102 / D−47 /
$109.99 / Paid / AS-BIL-00044; INV-00180 / SHP-10055 / D−65 / $199.98 / Paid /
AS-BIL-00031; INV-00131 / SHP-10012 / D−87 / $139.99 / Paid / AS-BIL-00019;
INV-00322 / SHP-10221 / D−1 / $239.98 / Posted / AS-BIL-00090.
SHP-10229 has no invoice (its posting failed, see §8).
Generated: one invoice per Delivered order, amount = order amount, Status Paid if older
than D−7 else Posted; set the order's Accounting Status to match (Posted/Reconciled).

## 8. Sync logs

SHP-10234 timeline (copy exactly; External Event ID `NFT-DEMO-10234-<n>`):

| n | Logged at | System | Event | Status | Message |
|---|---|---|---|---|---|
| 1 | D−2 09:12 | Shopify | Order received | Success | Order created. 3 units reserved at ShipMonk Warehouse. |
| 2 | D−2 09:13 | Salesforce | Stock reserved | Success | 3 units reserved at ShipMonk Warehouse. |
| 3 | D−2 09:40 | ShipMonk | Fulfilment request sent | Success | Request accepted by ShipMonk. |
| 4 | D−2 11:05 | ShipMonk | Order confirmed by 3PL | Success | All lines confirmed. |
| 5 | D−2 11:06 | Shopify | Order received | Duplicate Blocked | Same External Order ID received again. No new order or reservation created. |
| 6 | D−2 16:10 | ShipStation | Label and tracking | Success | Shipment SHP-00451 created, USPS Priority. |
| 7 | D−2 16:30 | Accounting Seed | Invoice post (simulated) | Success | Invoice INV-00318 posted. |
| 8 | D−1 14:20 | ShipStation | Label and tracking | Success | Shipment SHP-00463 created, UPS Ground. |
| 9 | D 08:02 | ShipStation | Tracking update | Failed | Carrier API timeout on shipment SHP-00463. No tracking update applied. |
| 10 | D 10:15 | ShipStation | Shipment delivered | Success | Shipment SHP-00451 delivered. |

The other two Failed logs (the only Failed rows in the org):
- D 07:45, Amazon FBA, Inventory sync, record ref GLID-BLK-08, no order, "Amazon SKU not
  mapped to a Salesforce product."
- D 06:30, Accounting Seed, Invoice post (simulated), order SHP-10229, "Revenue GL account
  missing for channel Shopify (demo rule)."

Also fixed: D 09:20 Shopify "Order received" SHP-10241 Success "Order created. 1 unit
reserved at ShipMonk Warehouse."; D 09:05 Amazon "Order received"
113-2209481-5530217 Success "FBA order created. 2 units reserved at Amazon FBA."

Generated: every other order gets 2–5 Success logs matching its status (Order received,
Stock reserved, Order confirmed, Label and tracking, Shipment delivered, Invoice post),
timed after its order date.
