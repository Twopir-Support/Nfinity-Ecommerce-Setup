/**
 * NFT demo: loads the dummy data from the NFT_DemoData_* static resources.
 * Every date in the data is an offset from today, so the demo always looks current.
 * All loads are upserts on external keys, so running them twice never duplicates records.
 *
 * Run in order (each is its own transaction):
 *   NFT_DemoDataLoader.loadCatalog();
 *   NFT_DemoDataLoader.loadOrders();
 *   NFT_DemoDataLoader.loadFulfilment();
 *   NFT_DemoDataLoader.loadLogs(1);  NFT_DemoDataLoader.loadLogs(2);  NFT_DemoDataLoader.loadLogs(3);
 *   NFT_DemoDataLoader.finish();
 */
public without sharing class NFT_DemoDataLoader {

    private static Map<String, Object> resource(String name) {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :name LIMIT 1];
        return (Map<String, Object>) JSON.deserializeUntyped(sr.Body.toString());
    }
    private static List<Object> list(Map<String, Object> m, String key) { return (List<Object>) m.get(key); }
    private static String str(Map<String, Object> m, String key) { Object o = m.get(key); return o == null ? null : String.valueOf(o); }
    private static Decimal num(Map<String, Object> m, String key) {
        Object o = m.get(key);
        if (o == null) { return null; }
        if (o instanceof Integer) { return Decimal.valueOf((Integer) o); }
        return (Decimal) o;
    }
    private static Date day(Object o) { return o == null ? null : Date.today().addDays((Integer) o); }
    private static Datetime stamp(Object o) {
        if (o == null) { return null; }
        Map<String, Object> m = (Map<String, Object>) o;
        String t = (String) m.get('t');
        return Datetime.newInstance(Date.today().addDays((Integer) m.get('d')),
                                    Time.newInstance(Integer.valueOf(t.left(2)), Integer.valueOf(t.right(2)), 0, 0));
    }

    // ------------------------------------------------------------------ catalog
    public static void loadCatalog() {
        Map<String, Object> data = resource('NFT_DemoData_Catalog');

        List<Product2> products = new List<Product2>();
        Map<String, Decimal> price = new Map<String, Decimal>();
        for (Object o : list(data, 'products')) {
            Map<String, Object> m = (Map<String, Object>) o;
            products.add(new Product2(Name = str(m, 'name'), ProductCode = str(m, 'sku'), NFT_SKU__c = str(m, 'sku'),
                NFT_Family__c = str(m, 'family'), NFT_Style__c = str(m, 'style'), NFT_Colour__c = str(m, 'colour'),
                NFT_Size__c = str(m, 'size'), IsActive = true));
            price.put(str(m, 'sku'), num(m, 'price'));
        }
        Database.upsert(products, Product2.NFT_SKU__c, true);

        Pricebook2 std = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!std.IsActive) { std.IsActive = true; update std; }
        Set<Id> priced = new Set<Id>();
        for (PricebookEntry e : [SELECT Product2Id FROM PricebookEntry WHERE Pricebook2Id = :std.Id AND Product2.NFT_SKU__c != null]) { priced.add(e.Product2Id); }
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Product2 p : products) {
            if (!priced.contains(p.Id)) {
                entries.add(new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p.Id, UnitPrice = price.get(p.NFT_SKU__c), IsActive = true, UseStandardPrice = false));
            }
        }
        insert entries;

        List<Account> accounts = new List<Account>();
        Map<String, Map<String, Object>> byKey = new Map<String, Map<String, Object>>();
        for (Object o : list(data, 'accounts')) {
            Map<String, Object> m = (Map<String, Object>) o;
            String key = str(m, 'key');
            byKey.put(key, m);
            Boolean shopify = str(m, 'source') == 'Shopify';
            accounts.add(new Account(Name = str(m, 'name'), NFT_Customer_Key__c = key, NFT_Customer_Source__c = str(m, 'source'),
                NFT_Rewards_Tier__c = str(m, 'tier'), NFT_Shopify_Customer_Id__c = shopify ? key : null,
                NFT_Amazon_Buyer_Id__c = shopify ? null : key, Phone = str(m, 'phone'),
                ShippingStreet = str(m, 'street'), ShippingCity = str(m, 'city'), ShippingState = str(m, 'state'),
                ShippingPostalCode = str(m, 'zip'), ShippingCountry = str(m, 'street') == null ? null : 'US',
                BillingStreet = str(m, 'street'), BillingCity = str(m, 'city'), BillingState = str(m, 'state'),
                BillingPostalCode = str(m, 'zip'), BillingCountry = str(m, 'street') == null ? null : 'US'));
        }
        Database.upsert(accounts, Account.NFT_Customer_Key__c, true);

        Set<String> emails = new Set<String>();
        for (Map<String, Object> m : byKey.values()) { emails.add(str(m, 'email')); }
        Set<String> existing = new Set<String>();
        for (Contact c : [SELECT Email FROM Contact WHERE Email IN :emails]) { existing.add(c.Email.toLowerCase()); }
        List<Contact> contacts = new List<Contact>();
        for (Account a : accounts) {
            Map<String, Object> m = byKey.get(a.NFT_Customer_Key__c);
            if (existing.contains(str(m, 'email').toLowerCase())) { continue; }
            contacts.add(new Contact(AccountId = a.Id, FirstName = str(m, 'first'), LastName = str(m, 'last'),
                                     Email = str(m, 'email'), Phone = str(m, 'phone')));
        }
        insert contacts;

        List<NFT_Inventory_Balance__c> balances = new List<NFT_Inventory_Balance__c>();
        for (Object o : list(data, 'balances')) {
            Map<String, Object> m = (Map<String, Object>) o;
            balances.add(new NFT_Inventory_Balance__c(Name = str(m, 'sku') + ' – ' + str(m, 'loc'), NFT_Unique_Key__c = str(m, 'key'),
                NFT_Product__r = new Product2(NFT_SKU__c = str(m, 'sku')), NFT_Location__c = str(m, 'loc'),
                NFT_Location_Type__c = str(m, 'type'), NFT_Qty_On_Hand__c = num(m, 'oh'), NFT_Qty_Reserved__c = num(m, 'res'),
                NFT_Qty_Inbound__c = num(m, 'inb'), NFT_Reorder_Point__c = num(m, 'rop'), NFT_Last_Updated_At__c = stamp(m.get('upd'))));
        }
        Database.upsert(balances, NFT_Inventory_Balance__c.NFT_Unique_Key__c, true);
    }

    // ------------------------------------------------------------------ orders + lines
    public static void loadOrders() {
        Map<String, Object> data = resource('NFT_DemoData_Orders');
        List<Object> rows = list(data, 'orders');

        Set<String> keys = new Set<String>();
        Set<String> exts = new Set<String>();
        for (Object o : rows) { Map<String, Object> m = (Map<String, Object>) o; keys.add(str(m, 'cust')); exts.add(str(m, 'ext')); }
        Map<String, Account> acc = new Map<String, Account>();
        for (Account a : [SELECT Id, NFT_Customer_Key__c, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
                          FROM Account WHERE NFT_Customer_Key__c IN :keys]) { acc.put(a.NFT_Customer_Key__c, a); }
        Set<String> existingExt = new Set<String>();
        for (Order o : [SELECT NFT_External_Order_Id__c FROM Order WHERE NFT_External_Order_Id__c IN :exts]) { existingExt.add(o.NFT_External_Order_Id__c); }
        Id pb = NFT_CommerceService.standardPricebookId();

        List<Order> orders = new List<Order>();
        for (Object o : rows) {
            Map<String, Object> m = (Map<String, Object>) o;
            Account a = acc.get(str(m, 'cust'));
            Datetime placed = stamp(m.get('od'));
            Order ord = new Order(AccountId = a.Id, EffectiveDate = placed.date(),
                NFT_External_Order_Id__c = str(m, 'ext'), NFT_Channel__c = str(m, 'ch'), NFT_Fulfillment_Provider__c = str(m, 'prov'),
                NFT_Fulfillment_Status__c = str(m, 'st'), NFT_Payment_Status__c = str(m, 'pay'), NFT_Shipping_Method__c = str(m, 'ship'),
                NFT_Accounting_Status__c = str(m, 'acct'), NFT_Received_At__c = placed,
                NFT_Confirmed_At__c = stamp(m.get('conf')), NFT_First_Shipped_At__c = stamp(m.get('fs')), NFT_Delivered_At__c = stamp(m.get('del')),
                NFT_Must_Ship_By__c = day(m.get('sb')), NFT_Must_Deliver_By__c = day(m.get('db')),
                ShippingStreet = a.ShippingStreet, ShippingCity = a.ShippingCity, ShippingState = a.ShippingState,
                ShippingPostalCode = a.ShippingPostalCode, ShippingCountry = a.ShippingCountry);
            if (!existingExt.contains(ord.NFT_External_Order_Id__c)) { ord.Pricebook2Id = pb; ord.Status = 'Draft'; }
            orders.add(ord);
        }
        Database.upsert(orders, Order.NFT_External_Order_Id__c, true);
        Map<String, Id> orderId = new Map<String, Id>();
        for (Order o : orders) { orderId.put(o.NFT_External_Order_Id__c, o.Id); }

        Map<String, PricebookEntry> pbe = new Map<String, PricebookEntry>();
        for (PricebookEntry e : [SELECT Id, Product2Id, Product2.NFT_SKU__c FROM PricebookEntry WHERE Pricebook2Id = :pb AND Product2.NFT_SKU__c != null]) {
            pbe.put(e.Product2.NFT_SKU__c, e);
        }
        Set<String> lineKeys = new Set<String>();
        for (Object o : rows) {
            Map<String, Object> m = (Map<String, Object>) o;
            for (Object l : list(m, 'lines')) { lineKeys.add(str(m, 'ext') + '-' + str((Map<String, Object>) l, 'no')); }
        }
        Map<String, Id> existingLine = new Map<String, Id>();
        for (OrderItem i : [SELECT Id, NFT_Line_Key__c FROM OrderItem WHERE NFT_Line_Key__c IN :lineKeys]) { existingLine.put(i.NFT_Line_Key__c, i.Id); }

        List<OrderItem> inserts = new List<OrderItem>();
        List<OrderItem> updates = new List<OrderItem>();
        for (Object o : rows) {
            Map<String, Object> m = (Map<String, Object>) o;
            String ext = str(m, 'ext');
            for (Object lo : list(m, 'lines')) {
                Map<String, Object> l = (Map<String, Object>) lo;
                String key = ext + '-' + str(l, 'no');
                OrderItem item = new OrderItem(Quantity = num(l, 'q'), UnitPrice = num(l, 'p'), NFT_Line_No__c = str(l, 'no'),
                    NFT_Qty_Confirmed__c = num(l, 'c'), NFT_Qty_Shipped__c = num(l, 's'), NFT_Qty_Invoiced__c = num(l, 'i'));
                if (existingLine.containsKey(key)) {
                    item.Id = existingLine.get(key);
                    updates.add(item);
                } else {
                    PricebookEntry e = pbe.get(str(l, 'sku'));
                    item.OrderId = orderId.get(ext);
                    item.PricebookEntryId = e.Id;
                    item.Product2Id = e.Product2Id;
                    item.NFT_Line_Key__c = key;
                    inserts.add(item);
                }
            }
        }
        insert inserts;
        update updates;
    }

    // ------------------------------------------------------------------ shipments + invoices
    public static void loadFulfilment() {
        Map<String, Object> data = resource('NFT_DemoData_Fulfilment');
        List<NFT_Shipment__c> ships = new List<NFT_Shipment__c>();
        for (Object o : list(data, 'shipments')) {
            Map<String, Object> m = (Map<String, Object>) o;
            ships.add(new NFT_Shipment__c(Name = str(m, 'name'), NFT_Tracking_Number__c = str(m, 'trk'),
                NFT_Order__r = new Order(NFT_External_Order_Id__c = str(m, 'ord')),
                NFT_Account__r = new Account(NFT_Customer_Key__c = str(m, 'cust')),
                NFT_Provider__c = str(m, 'prov'), NFT_Carrier__c = str(m, 'car'), NFT_Sequence__c = str(m, 'seq'),
                NFT_Units__c = num(m, 'u'), NFT_Contents__c = str(m, 'cont'), NFT_Status__c = str(m, 'st'),
                NFT_Shipped_At__c = stamp(m.get('sa')), NFT_Expected_Delivery__c = day(m.get('exp')), NFT_Delivered_At__c = stamp(m.get('da'))));
        }
        Database.upsert(ships, NFT_Shipment__c.NFT_Tracking_Number__c, true);

        List<NFT_Invoice__c> invs = new List<NFT_Invoice__c>();
        for (Object o : list(data, 'invoices')) {
            Map<String, Object> m = (Map<String, Object>) o;
            invs.add(new NFT_Invoice__c(Name = str(m, 'name'), NFT_Accounting_Seed_Ref__c = str(m, 'ref'),
                NFT_Order__r = new Order(NFT_External_Order_Id__c = str(m, 'ord')),
                NFT_Account__r = new Account(NFT_Customer_Key__c = str(m, 'cust')),
                NFT_Invoice_Date__c = day(m.get('d')), NFT_Amount__c = num(m, 'amt'), NFT_Status__c = str(m, 'st')));
        }
        Database.upsert(invs, NFT_Invoice__c.NFT_Accounting_Seed_Ref__c, true);
    }

    // ------------------------------------------------------------------ sync logs
    public static void loadLogs(Integer part) {
        Map<String, Object> data = resource('NFT_DemoData_Logs' + String.valueOf(part));
        List<NFT_Sync_Log__c> logs = new List<NFT_Sync_Log__c>();
        for (Object o : list(data, 'logs')) {
            Map<String, Object> m = (Map<String, Object>) o;
            NFT_Sync_Log__c l = new NFT_Sync_Log__c(NFT_External_Event_Id__c = str(m, 'id'), NFT_Record_Ref__c = str(m, 'ref'),
                NFT_System__c = str(m, 'sys'), NFT_Event__c = str(m, 'ev'), NFT_Status__c = str(m, 'st'),
                NFT_Message__c = str(m, 'msg'), NFT_Logged_At__c = stamp(m.get('at')), NFT_Attempts__c = 1);
            if (str(m, 'ord') != null) { l.NFT_Order__r = new Order(NFT_External_Order_Id__c = str(m, 'ord')); }
            logs.add(l);
        }
        Database.upsert(logs, NFT_Sync_Log__c.NFT_External_Event_Id__c, true);
    }

    // ------------------------------------------------------------------ final totals
    public static void finish() {
        Set<Id> accountIds = new Map<Id, Account>([SELECT Id FROM Account WHERE NFT_Customer_Key__c != null]).keySet();
        NFT_TriggerHandler.recalcAccounts(new Set<Id>(accountIds));
        Set<Id> productIds = new Map<Id, Product2>([SELECT Id FROM Product2 WHERE NFT_SKU__c != null]).keySet();
        NFT_TriggerHandler.recalcProducts(new Set<Id>(productIds));
    }
}
