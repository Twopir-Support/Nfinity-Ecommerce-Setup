# 07 – Verification

Write these checks into `scripts/verify.sh`. Run after each stage (the parts that
apply) and in full at the end. Paste the results into `BUILD-REPORT.md`.

## 1. Prefix check (before every commit)

Fail if any file Claude created under `force-app/main/default/` has a component name
that does not start with `NFT` (case-insensitive `nft` for LWC folders). Allowed
exceptions, because they are existing standard components being extended:
`objects/Account|Contact|Product2|Order|OrderItem/` folder names (their new fields must
still start with `NFT_`), `settings/Order.settings-meta.xml`, and quick actions named
`<StandardObject>.NFT_…`.

```bash
find force-app/main/default -type f -name "*-meta.xml" \
 | grep -vE '/objects/(Account|Contact|Product2|Order|OrderItem)/[^/]+-meta.xml$' \
 | grep -vE 'settings/Order' \
 | while read f; do n=$(basename "$f" | sed -E 's/\..*//'); \
     case "$n" in NFT*|nft*|*.NFT_*) ;; *) echo "MISSING PREFIX: $f";; esac; done
```
(Adjust the parser for `Order.NFT_Ship.quickAction-meta.xml`, field files under
standard objects, and list views; the rule is the component's own name starts with NFT.)

## 2. Components exist in the org

```bash
sf org list metadata -m CustomObject      | grep -c '^NFT_'   # expect 4
sf org list metadata -m CustomField       # every NFT field in specs/02 present
sf org list metadata -m Flow              | grep NFT_         # expect 12, all Active:
sf data query -q "SELECT ApiName, ActiveVersionId FROM FlowDefinitionView WHERE ApiName LIKE 'NFT_%'" 
sf org list metadata -m FlexiPage         | grep NFT_         # 5 (4 pages + utility bar)
sf org list metadata -m LightningComponentBundle | grep nft    # nftOrderLineStatus
sf org list metadata -m QuickAction       | grep NFT_         # 7
sf org list metadata -m Report --folder NFT_Demo_Reports      # 10
sf org list metadata -m Dashboard --folder NFT_Demo_Dashboards # 1
sf org list metadata -m CustomApplication | grep NFT_         # 1
sf org list metadata -m PermissionSet     | grep NFT_         # 1, and assigned to running user
```

## 3. Data matches the preview

| Check | Query | Expect |
|---|---|---|
| Products | `SELECT COUNT() FROM Product2 WHERE NFT_SKU__c != null` | 34 |
| Balances | `SELECT COUNT() FROM NFT_Inventory_Balance__c` | 68 |
| Low stock | `SELECT COUNT() FROM NFT_Inventory_Balance__c WHERE NFT_Low_Stock__c = true` | 6 |
| Hero order | `SELECT NFT_Fulfillment_Status__c, TotalAmount, NFT_Pct_Confirmed__c, NFT_Pct_Shipped__c, NFT_Pct_Invoiced__c FROM Order WHERE NFT_External_Order_Id__c = 'SHP-10234'` | Partially Shipped, 369.97, 100, 67, 33 |
| Hero shipments | `SELECT Name, NFT_Status__c FROM NFT_Shipment__c WHERE NFT_Order__r.NFT_External_Order_Id__c = 'SHP-10234'` | SHP-00451 Delivered, SHP-00463 In Transit |
| Hero timeline | `SELECT COUNT() FROM NFT_Sync_Log__c WHERE NFT_Order__r.NFT_External_Order_Id__c = 'SHP-10234'` | 10 |
| Hero failed count | `SELECT NFT_Failed_Sync_Count__c FROM Order WHERE NFT_External_Order_Id__c = 'SHP-10234'` | 1 |
| Madison | `SELECT NFT_Total_Orders__c, NFT_Open_Orders__c, NFT_Lifetime_Spend__c FROM Account WHERE NFT_Customer_Key__c = 'SC-500231'` | 6, 2, 1114.91 |
| Apex White 7 totals | `SELECT NFT_Total_On_Hand__c, NFT_Total_Reserved__c, NFT_Total_Available__c, NFT_Total_Inbound__c FROM Product2 WHERE NFT_SKU__c = 'APEX-WHT-07'` | 48, 9, 39, 48 |
| KPI: new today | `SELECT COUNT() FROM Order WHERE EffectiveDate = TODAY AND NFT_External_Order_Id__c != null` | 18 |
| KPI: awaiting | `… WHERE NFT_Fulfillment_Status__c IN ('Received','Confirmed')` | 27 |
| KPI: FBA 30 days | `… WHERE NFT_Fulfillment_Provider__c = 'Amazon FBA' AND EffectiveDate = LAST_N_DAYS:30` | 74 |
| KPI: late | `… WHERE NFT_Late_Shipment__c = true` | 4 |
| KPI: sync errors | `SELECT COUNT() FROM NFT_Sync_Log__c WHERE NFT_Status__c = 'Failed' AND NFT_Logged_At__c = LAST_N_DAYS:1` | 3 |
| Orders stay Draft | `SELECT COUNT() FROM Order WHERE Status != 'Draft' AND NFT_External_Order_Id__c != null` | 0 |

## 4. Flow smoke test

Screen flows cannot be run from the CLI, so test the record-triggered flows with a
throwaway record set (keys prefixed `NFT-TEST-`), then delete them:
1. Insert an Order with 1 OrderItem for SC-500244 → Ava's Total Orders goes up by 1 (F10).
2. Update an Inventory Balance's On Hand by +1 → its Product's Total On Hand goes up by 1 (F9).
3. Insert a Failed Sync Log on that test order → the order's Failed Sync Count = 1 (F11).
4. Delete the test records, restore the balance, and re-run §3: all checks still pass.

Screen flows F1–F8 are checked by the user in §5.

## 4a. Reset script

Write `scripts/reset_demo.sh`: delete every NFT-related record created after the last
load (Orders, OrderItems, Shipments, Invoices, Sync Logs with CreatedDate after the
load time stored in `data/.last_load`), then re-run `scripts/load_data.sh`. Use it
after a rehearsal so the demo starts from the same state.

## 5. User's visual check (ask the user to do this)

Open the app and follow this path, comparing with `reference/ui-reference.html`:
1. Operations Home: 6 tiles show 18, 27, 74, 4, 6, 3. Click each of the 5 tabs.
2. Open order SHP-10234: path at Partially Shipped; tiles 100% / 67% / 33%; line 01 amber;
   failed-sync alert; timeline of 10 events; 2 shipments; 1 invoice.
3. Click "(Simulated) Ship" on SHP-10239 and confirm a shipment appears and stock drops.
4. Open product APEX-WHT-07: ShipMonk row Available 0 and Low stock.
5. Open account Madison Carter: 6 orders, $1,114.91, 1 at-risk order.
6. Utility bar: "Simulate Shopify Order" creates an order; resending the same ID shows
   "Duplicate blocked"; "Retry Failed Syncs" clears the Sync errors tile.

## 6. BUILD-REPORT.md

Sections: target org (alias, org Id, type), what was deployed (table: component, type,
status BUILT / FAILED / DEVIATED, verification), data checks (§3 results), deviations
and why, open items for the user, and the Git commit list.
