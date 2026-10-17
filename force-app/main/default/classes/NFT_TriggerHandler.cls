/**
 * NFT demo: keeps roll-up style totals that standard roll-ups cannot do
 * (Account totals, Product totals, Order failed-sync count).
 * Only touches records that belong to the NFT demo (orders with an External Order ID).
 * Also fills the Standard Price Book on demo orders and lines inserted without one
 * (the data/ JSON tree import cannot know the org's price book Id).
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

    // before insert on Order: NFT demo orders without a price book get the standard one
    public static void defaultPricebook(List<Order> rows) {
        List<Order> todo = new List<Order>();
        for (Order o : rows) { if (o.Pricebook2Id == null && o.NFT_External_Order_Id__c != null) { todo.add(o); } }
        if (todo.isEmpty()) { return; }
        Id pb = NFT_CommerceService.standardPricebookId();
        if (!Test.isRunningTest()) {
            Pricebook2 std = [SELECT Id, IsActive FROM Pricebook2 WHERE Id = :pb];
            if (!std.IsActive) { std.IsActive = true; update std; }
        }
        for (Order o : todo) { o.Pricebook2Id = pb; }
    }

    // before insert on OrderItem: lines with only Product2Id get the standard price book entry,
    // which is created from the line's unit price if the product has none yet
    public static void defaultPricebookEntries(List<OrderItem> rows) {
        List<OrderItem> todo = new List<OrderItem>();
        Set<Id> productIds = new Set<Id>();
        for (OrderItem i : rows) {
            if (i.PricebookEntryId == null && i.Product2Id != null) { todo.add(i); productIds.add(i.Product2Id); }
        }
        if (todo.isEmpty()) { return; }
        Id pb = NFT_CommerceService.standardPricebookId();
        Map<Id, PricebookEntry> entries = new Map<Id, PricebookEntry>();
        for (PricebookEntry e : [SELECT Id, Product2Id, IsActive FROM PricebookEntry WHERE Pricebook2Id = :pb AND Product2Id IN :productIds]) {
            entries.put(e.Product2Id, e);
        }
        List<PricebookEntry> inserts = new List<PricebookEntry>();
        List<PricebookEntry> toActivate = new List<PricebookEntry>();
        for (OrderItem i : todo) {
            PricebookEntry e = entries.get(i.Product2Id);
            if (e == null) {
                e = new PricebookEntry(Pricebook2Id = pb, Product2Id = i.Product2Id, UnitPrice = i.UnitPrice, IsActive = true, UseStandardPrice = false);
                entries.put(i.Product2Id, e);
                inserts.add(e);
            } else if (!e.IsActive) {
                e.IsActive = true;
                toActivate.add(e);
            }
        }
        insert inserts;
        update toActivate;
        for (OrderItem i : todo) { i.PricebookEntryId = entries.get(i.Product2Id).Id; }
    }
}
