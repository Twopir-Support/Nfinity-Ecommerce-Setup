// NFT demo: prints CHECK lines. Every line should read PASS.
Map<String, List<Object>> c = new Map<String, List<Object>>();
c.put('Products = 34', new List<Object>{ [SELECT COUNT() FROM Product2 WHERE NFT_SKU__c != null], 34 });
c.put('Inventory balances = 68', new List<Object>{ [SELECT COUNT() FROM NFT_Inventory_Balance__c], 68 });
c.put('Low-stock SKUs = 6', new List<Object>{ [SELECT COUNT() FROM NFT_Inventory_Balance__c WHERE NFT_Low_Stock__c = true], 6 });
c.put('New orders today = 18', new List<Object>{ [SELECT COUNT() FROM Order WHERE EffectiveDate = TODAY AND NFT_External_Order_Id__c != null], 18 });
c.put('Awaiting shipment = 27', new List<Object>{ [SELECT COUNT() FROM Order WHERE NFT_Fulfillment_Status__c IN ('Received','Confirmed')], 27 });
c.put('FBA orders 30 days = 74', new List<Object>{ [SELECT COUNT() FROM Order WHERE NFT_Fulfillment_Provider__c = 'Amazon FBA' AND EffectiveDate = LAST_N_DAYS:30], 74 });
c.put('Late shipments = 4', new List<Object>{ [SELECT COUNT() FROM Order WHERE NFT_Late_Shipment__c = true], 4 });
c.put('Sync errors = 3', new List<Object>{ [SELECT COUNT() FROM NFT_Sync_Log__c WHERE NFT_Status__c = 'Failed' AND NFT_Logged_At__c = LAST_N_DAYS:1], 3 });
c.put('Orders not Draft = 0', new List<Object>{ [SELECT COUNT() FROM Order WHERE Status != 'Draft' AND NFT_External_Order_Id__c != null], 0 });
c.put('SHP-10234 timeline = 10', new List<Object>{ [SELECT COUNT() FROM NFT_Sync_Log__c WHERE NFT_Order__r.NFT_External_Order_Id__c = 'SHP-10234'], 10 });
Order h = [SELECT NFT_Fulfillment_Status__c, TotalAmount, NFT_Pct_Shipped__c, NFT_Pct_Invoiced__c, NFT_Failed_Sync_Count__c FROM Order WHERE NFT_External_Order_Id__c = 'SHP-10234'];
c.put('SHP-10234 status = Partially Shipped', new List<Object>{ h.NFT_Fulfillment_Status__c, 'Partially Shipped' });
c.put('SHP-10234 amount = 369.97', new List<Object>{ h.TotalAmount, 369.97 });
c.put('SHP-10234 failed syncs = 1', new List<Object>{ h.NFT_Failed_Sync_Count__c, 1 });
Account m = [SELECT NFT_Total_Orders__c, NFT_Open_Orders__c, NFT_Lifetime_Spend__c FROM Account WHERE NFT_Customer_Key__c = 'SC-500231'];
c.put('Madison total orders = 6', new List<Object>{ m.NFT_Total_Orders__c, 6 });
c.put('Madison open orders = 2', new List<Object>{ m.NFT_Open_Orders__c, 2 });
c.put('Madison lifetime spend = 1114.91', new List<Object>{ m.NFT_Lifetime_Spend__c, 1114.91 });
Product2 p = [SELECT NFT_Total_On_Hand__c, NFT_Total_Available__c FROM Product2 WHERE NFT_SKU__c = 'APEX-WHT-07'];
c.put('APEX-WHT-07 on hand = 48', new List<Object>{ p.NFT_Total_On_Hand__c, 48 });
c.put('APEX-WHT-07 available = 39', new List<Object>{ p.NFT_Total_Available__c, 39 });
Integer fails = 0;
for (String k : c.keySet()) {
    Object got = c.get(k)[0], want = c.get(k)[1];
    Boolean ok = String.valueOf(got) == String.valueOf(want) || (got instanceof Decimal && want instanceof Decimal && (Decimal) got == (Decimal) want)
        || (got instanceof Decimal && want instanceof Integer && (Decimal) got == (Integer) want);
    if (!ok) { fails++; }
    System.debug(LoggingLevel.ERROR, 'CHECK ' + (ok ? 'PASS ' : 'FAIL ') + k + ' (got ' + String.valueOf(got) + ')');
}
System.debug(LoggingLevel.ERROR, 'CHECK SUMMARY: ' + (fails == 0 ? 'ALL PASS' : String.valueOf(fails) + ' FAILED'));
