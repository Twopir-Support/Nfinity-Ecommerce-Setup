/**
 * NFT demo: keeps roll-up style totals that standard roll-ups cannot do
 * (Account totals, Product totals, Order failed-sync count).
 * Only touches records that belong to the NFT demo (orders with an External Order ID).
 */
public without sharing class NFT_TriggerHandler {

    public static void recalcAccounts(Set<Id> accountIds) {
        accountIds.remove(null);
        if (accountIds.isEmpty()) { return; }
        Map<Id, Account> accs = new Map<Id, Account>([SELECT Id, NFT_Total_Orders__c, NFT_Open_Orders__c, NFT_Lifetime_Spend__c, NFT_Last_Order_Date__c
                                                       FROM Account WHERE Id IN :accountIds]);
        Map<Id, Account> next = new Map<Id, Account>();
        for (Id i : accs.keySet()) {
            next.put(i, new Account(Id = i, NFT_Total_Orders__c = 0, NFT_Open_Orders__c = 0, NFT_Lifetime_Spend__c = 0, NFT_Last_Order_Date__c = null));
        }
        for (AggregateResult ar : [SELECT AccountId a, COUNT(Id) c, MAX(EffectiveDate) d FROM Order
                                   WHERE AccountId IN :accountIds AND NFT_External_Order_Id__c != null GROUP BY AccountId]) {
            Account a = next.get((Id) ar.get('a'));
            a.NFT_Total_Orders__c = (Integer) ar.get('c');
            a.NFT_Last_Order_Date__c = (Date) ar.get('d');
        }
        for (AggregateResult ar : [SELECT AccountId a, COUNT(Id) c FROM Order
                                   WHERE AccountId IN :accountIds AND NFT_External_Order_Id__c != null AND NFT_Is_Open__c = true GROUP BY AccountId]) {
            next.get((Id) ar.get('a')).NFT_Open_Orders__c = (Integer) ar.get('c');
        }
        for (AggregateResult ar : [SELECT AccountId a, SUM(TotalAmount) s FROM Order
                                   WHERE AccountId IN :accountIds AND NFT_External_Order_Id__c != null AND NFT_Fulfillment_Status__c != 'Cancelled' GROUP BY AccountId]) {
            next.get((Id) ar.get('a')).NFT_Lifetime_Spend__c = (Decimal) ar.get('s');
        }
        List<Account> changed = new List<Account>();
        for (Account n : next.values()) {
            Account o = accs.get(n.Id);
            if (o.NFT_Total_Orders__c != n.NFT_Total_Orders__c || o.NFT_Open_Orders__c != n.NFT_Open_Orders__c
                || o.NFT_Lifetime_Spend__c != n.NFT_Lifetime_Spend__c || o.NFT_Last_Order_Date__c != n.NFT_Last_Order_Date__c) {
                changed.add(n);
            }
        }
        if (!changed.isEmpty()) { update changed; }
    }

    public static void recalcAccountsForOrders(Set<Id> orderIds) {
        orderIds.remove(null);
        if (orderIds.isEmpty()) { return; }
        Set<Id> accountIds = new Set<Id>();
        for (Order o : [SELECT AccountId FROM Order WHERE Id IN :orderIds AND NFT_External_Order_Id__c != null]) { accountIds.add(o.AccountId); }
        recalcAccounts(accountIds);
    }

    public static void recalcProducts(Set<Id> productIds) {
        productIds.remove(null);
        if (productIds.isEmpty()) { return; }
        Map<Id, Product2> next = new Map<Id, Product2>();
        for (Id i : productIds) {
            next.put(i, new Product2(Id = i, NFT_Total_On_Hand__c = 0, NFT_Total_Reserved__c = 0, NFT_Total_Available__c = 0, NFT_Total_Inbound__c = 0));
        }
        for (AggregateResult ar : [SELECT NFT_Product__c p, SUM(NFT_Qty_On_Hand__c) h, SUM(NFT_Qty_Reserved__c) r, SUM(NFT_Qty_Inbound__c) i
                                   FROM NFT_Inventory_Balance__c WHERE NFT_Product__c IN :productIds GROUP BY NFT_Product__c]) {
            Product2 p = next.get((Id) ar.get('p'));
            Decimal h = ar.get('h') == null ? 0 : (Decimal) ar.get('h');
            Decimal r = ar.get('r') == null ? 0 : (Decimal) ar.get('r');
            p.NFT_Total_On_Hand__c = h;
            p.NFT_Total_Reserved__c = r;
            p.NFT_Total_Available__c = h - r;
            p.NFT_Total_Inbound__c = ar.get('i') == null ? 0 : (Decimal) ar.get('i');
        }
        update next.values();
    }

    public static void recalcFailedSyncs(Set<Id> orderIds) {
        orderIds.remove(null);
        if (orderIds.isEmpty()) { return; }
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (Id i : orderIds) { counts.put(i, 0); }
        for (AggregateResult ar : [SELECT NFT_Order__c o, COUNT(Id) c FROM NFT_Sync_Log__c
                                   WHERE NFT_Order__c IN :orderIds AND NFT_Status__c = 'Failed' GROUP BY NFT_Order__c]) {
            counts.put((Id) ar.get('o'), (Integer) ar.get('c'));
        }
        List<Order> changed = new List<Order>();
        for (Order o : [SELECT Id, NFT_Failed_Sync_Count__c FROM Order WHERE Id IN :orderIds]) {
            if (o.NFT_Failed_Sync_Count__c != counts.get(o.Id)) { changed.add(new Order(Id = o.Id, NFT_Failed_Sync_Count__c = counts.get(o.Id))); }
        }
        if (!changed.isEmpty()) { update changed; }
    }
}
