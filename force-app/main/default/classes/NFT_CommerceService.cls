/**
 * NFT demo: all simulated integration behaviour (Shopify, Amazon/FBA, ShipMonk,
 * ShipStation, Accounting Seed). Called by the NFT screen flows through the
 * NFT_*Action invocable classes. Nothing here calls an external system.
 */
public with sharing class NFT_CommerceService {

    public class Result {
        public String message;
        public Id recordId;
        public Result(String message, Id recordId) { this.message = message; this.recordId = recordId; }
    }

    public static final String SHIPMONK = 'ShipMonk';
    public static final String FBA = 'Amazon FBA';

    public static Id standardPricebookId() {
        if (Test.isRunningTest()) { return Test.getStandardPricebookId(); }
        return [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
    }

    public static String locationFor(String provider) {
        return provider == FBA ? 'Amazon FBA' : 'ShipMonk Warehouse';
    }

    private static String digits(Integer n) {
        String s = '';
        while (s.length() < n) { s += String.valueOf(Math.abs(Crypto.getRandomInteger())); }
        return s.left(n);
    }

    private static String pad(Integer n, Integer width) {
        String s = String.valueOf(n);
        while (s.length() < width) { s = '0' + s; }
        return s;
    }

    /** Next "PREFIX-00000" name for NFT_Shipment__c or NFT_Invoice__c. */
    public static String nextName(String prefix, String sobjectName) {
        String likeValue = prefix + '%';
        List<SObject> rows = Database.query('SELECT Name FROM ' + sobjectName + ' WHERE Name LIKE :likeValue ORDER BY Name DESC LIMIT 1');
        Integer next = 100;
        if (!rows.isEmpty()) {
            String last = (String) rows[0].get('Name');
            try { next = Integer.valueOf(last.substringAfter(prefix)) + 1; } catch (Exception e) { next = 100; }
        }
        return prefix + pad(next, 5);
    }

    private static String nextExternalId(String channel) {
        for (Integer i = 0; i < 25; i++) {
            String candidate;
            if (channel == 'Amazon') {
                candidate = '11' + digits(1) + '-' + digits(7) + '-' + digits(7);
            } else {
                Integer base = 10300 + [SELECT COUNT() FROM Order WHERE NFT_Channel__c = 'Shopify'] + i;
                candidate = 'SHP-' + String.valueOf(base);
            }
            if ([SELECT COUNT() FROM Order WHERE NFT_External_Order_Id__c = :candidate] == 0) { return candidate; }
        }
        return 'SHP-' + digits(6);
    }

    private static String trackingFor(String carrier) {
        if (carrier == 'UPS Ground') { return '1Z84A7W00344' + digits(5); }
        if (carrier == 'USPS Priority') { return '94055036993' + digits(8); }
        if (carrier == 'FedEx Ground') { return digits(12); }
        if (carrier == 'DHL eCommerce') { return 'GM' + digits(16); }
        return 'TBA3188452' + digits(5);
    }

    private static Order loadOrder(Id orderId) {
        List<Order> rows = [
            SELECT Id, AccountId, NFT_Channel__c, NFT_External_Order_Id__c, NFT_Fulfillment_Provider__c,
                   NFT_Fulfillment_Status__c, NFT_First_Shipped_At__c, NFT_Total_Units__c, NFT_Units_Shipped__c,
                   (SELECT Id, Product2Id, Product2.Name, Product2.NFT_SKU__c, Quantity, UnitPrice,
                           NFT_Qty_Confirmed__c, NFT_Qty_Shipped__c, NFT_Qty_Invoiced__c, NFT_Line_No__c
                    FROM OrderItems ORDER BY NFT_Line_No__c)
            FROM Order WHERE Id = :orderId LIMIT 1];
        if (rows.isEmpty()) { throw new NFT_Exception('Order not found.'); }
        return rows[0];
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    // ------------------------------------------------------------------ new order
    public static Result createOrder(String channel, Id accountId, String customerKey,
                                     List<String> skus, List<Decimal> qtys, String externalOrderId, Boolean resend) {
        Boolean amazon = channel == 'Amazon';
        String provider = amazon ? FBA : SHIPMONK;
        String systemName = amazon ? 'Amazon' : 'Shopify';
        String location = locationFor(provider);
        String extId = String.isBlank(externalOrderId) ? null : externalOrderId.trim();

        if (resend == true) {
            List<Order> last = [SELECT NFT_External_Order_Id__c FROM Order
                                WHERE NFT_Channel__c = :channel AND NFT_External_Order_Id__c != null
                                ORDER BY CreatedDate DESC LIMIT 1];
            if (!last.isEmpty()) { extId = last[0].NFT_External_Order_Id__c; }
        }
        if (extId != null) {
            List<Order> existing = [SELECT Id FROM Order WHERE NFT_External_Order_Id__c = :extId LIMIT 1];
            if (!existing.isEmpty()) {
                insert NFT_SyncLogger.build(existing[0].Id, extId, systemName, 'Order received', 'Duplicate Blocked',
                    'Same External Order ID received again. No new order or reservation created.');
                return new Result('Duplicate blocked: ' + extId + ' already exists. No new order or reservation was created.', existing[0].Id);
            }
        } else {
            extId = nextExternalId(channel);
        }

        Account acc;
        if (accountId != null) {
            acc = [SELECT Id, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry FROM Account WHERE Id = :accountId];
        } else {
            String key = String.isBlank(customerKey) ? (amazon ? 'AMZ-MASKED' : null) : customerKey.trim();
            if (key == null) { throw new NFT_Exception('Enter a Customer Key, for example SC-500244.'); }
            List<Account> accs = [SELECT Id, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry FROM Account WHERE NFT_Customer_Key__c = :key LIMIT 1];
            if (accs.isEmpty()) { throw new NFT_Exception('No customer with key ' + key + '.'); }
            acc = accs[0];
        }

        Id pb = standardPricebookId();
        Set<String> skuSet = new Set<String>();
        for (String s : skus) { if (!String.isBlank(s)) { skuSet.add(s.trim()); } }
        Map<String, PricebookEntry> pbe = new Map<String, PricebookEntry>();
        for (PricebookEntry e : [SELECT Id, UnitPrice, Product2Id, Product2.NFT_SKU__c FROM PricebookEntry
                                 WHERE Pricebook2Id = :pb AND IsActive = true AND Product2.NFT_SKU__c IN :skuSet]) {
            pbe.put(e.Product2.NFT_SKU__c, e);
        }

        List<OrderItem> items = new List<OrderItem>();
        Decimal total = 0;
        Decimal units = 0;
        for (Integer i = 0; i < skus.size(); i++) {
            String sku = String.isBlank(skus[i]) ? null : skus[i].trim();
            Decimal q = (qtys.size() > i && qtys[i] != null) ? qtys[i] : 0;
            if (sku == null || q <= 0) { continue; }
            if (!pbe.containsKey(sku)) { throw new NFT_Exception('Unknown SKU ' + sku + '.'); }
            PricebookEntry e = pbe.get(sku);
            String lineNo = pad(items.size() + 1, 2);
            items.add(new OrderItem(PricebookEntryId = e.Id, Product2Id = e.Product2Id, Quantity = q, UnitPrice = e.UnitPrice,
                                    NFT_Line_No__c = lineNo, NFT_Line_Key__c = extId + '-' + lineNo));
            total += q * e.UnitPrice;
            units += q;
        }
        if (items.isEmpty()) { throw new NFT_Exception('Add at least one SKU with a quantity above 0.'); }

        Order o = new Order(
            AccountId = acc.Id, Pricebook2Id = pb, EffectiveDate = Date.today(), Status = 'Draft',
            NFT_Channel__c = channel, NFT_External_Order_Id__c = extId, NFT_Fulfillment_Provider__c = provider,
            NFT_Fulfillment_Status__c = 'Received', NFT_Received_At__c = Datetime.now(),
            NFT_Must_Ship_By__c = Date.today().addDays(2), NFT_Must_Deliver_By__c = Date.today().addDays(7),
            NFT_Payment_Status__c = 'Paid', NFT_Shipping_Method__c = total > 150 ? 'Free over $150' : 'Standard',
            ShippingStreet = acc.ShippingStreet, ShippingCity = acc.ShippingCity, ShippingState = acc.ShippingState,
            ShippingPostalCode = acc.ShippingPostalCode, ShippingCountry = acc.ShippingCountry);
        insert o;
        for (OrderItem it : items) { it.OrderId = o.Id; }
        insert items;

        reserve(items, location);

        insert new List<NFT_Sync_Log__c>{
            NFT_SyncLogger.build(o.Id, extId, systemName, 'Order received', 'Success',
                (amazon ? 'FBA order created. ' : 'Order created. ') + String.valueOf(units.intValue()) + ' unit(s) reserved at ' + location + '.'),
            NFT_SyncLogger.build(o.Id, extId, 'Salesforce', 'Stock reserved', 'Success',
                String.valueOf(units.intValue()) + ' unit(s) reserved at ' + location + '.')
        };
        return new Result('Order ' + extId + ' created with ' + String.valueOf(units.intValue()) + ' unit(s) reserved at ' + location + '.', o.Id);
    }

    private static void reserve(List<OrderItem> items, String location) {
        Set<Id> productIds = new Set<Id>();
        for (OrderItem it : items) { productIds.add(it.Product2Id); }
        Map<Id, NFT_Inventory_Balance__c> byProduct = new Map<Id, NFT_Inventory_Balance__c>();
        for (NFT_Inventory_Balance__c b : [SELECT Id, NFT_Product__c, NFT_Qty_Reserved__c FROM NFT_Inventory_Balance__c
                                           WHERE NFT_Product__c IN :productIds AND NFT_Location__c = :location]) {
            byProduct.put(b.NFT_Product__c, b);
        }
        for (OrderItem it : items) {
            NFT_Inventory_Balance__c b = byProduct.get(it.Product2Id);
            if (b != null) { b.NFT_Qty_Reserved__c = nz(b.NFT_Qty_Reserved__c) + it.Quantity; b.NFT_Last_Updated_At__c = Datetime.now(); }
        }
        update byProduct.values();
    }

    // ------------------------------------------------------------------ 3PL confirm
    public static Result confirm(Id orderId) {
        Order o = loadOrder(orderId);
        if (o.NFT_Fulfillment_Status__c != 'Received') {
            return new Result('This order is already ' + o.NFT_Fulfillment_Status__c + '. Nothing to confirm.', o.Id);
        }
        for (OrderItem it : o.OrderItems) { it.NFT_Qty_Confirmed__c = it.Quantity; }
        update o.OrderItems;
        update new Order(Id = o.Id, NFT_Fulfillment_Status__c = 'Confirmed', NFT_Confirmed_At__c = Datetime.now());
        String sys = o.NFT_Fulfillment_Provider__c == FBA ? 'Amazon FBA' : 'ShipMonk';
        insert new List<NFT_Sync_Log__c>{
            NFT_SyncLogger.build(o.Id, o.NFT_External_Order_Id__c, sys, 'Fulfilment request sent', 'Success', 'Request accepted by ' + sys + '.'),
            NFT_SyncLogger.build(o.Id, o.NFT_External_Order_Id__c, sys, 'Order confirmed by 3PL', 'Success', 'All lines confirmed.')
        };
        return new Result('Confirmed by ' + sys + ' (simulated).', o.Id);
    }

    // ------------------------------------------------------------------ ship
    public static Result ship(Id orderId, String carrier, String mode) {
        Order o = loadOrder(orderId);
        if (o.NFT_Fulfillment_Status__c != 'Confirmed' && o.NFT_Fulfillment_Status__c != 'Partially Shipped') {
            return new Result('Only Confirmed or Partially Shipped orders can ship. This order is ' + o.NFT_Fulfillment_Status__c + '.', o.Id);
        }
        Boolean fba = o.NFT_Fulfillment_Provider__c == FBA;
        String useCarrier = fba ? 'Amazon Logistics' : (String.isBlank(carrier) ? 'UPS Ground' : carrier);
        String location = locationFor(o.NFT_Fulfillment_Provider__c);

        Set<Id> productIds = new Set<Id>();
        for (OrderItem it : o.OrderItems) { productIds.add(it.Product2Id); }
        Map<Id, NFT_Inventory_Balance__c> bal = new Map<Id, NFT_Inventory_Balance__c>();
        for (NFT_Inventory_Balance__c b : [SELECT Id, NFT_Product__c, NFT_Qty_On_Hand__c, NFT_Qty_Reserved__c FROM NFT_Inventory_Balance__c
                                           WHERE NFT_Product__c IN :productIds AND NFT_Location__c = :location]) {
            bal.put(b.NFT_Product__c, b);
        }

        Decimal totalUnits = 0;
        List<String> parts = new List<String>();
        List<OrderItem> changed = new List<OrderItem>();
        for (OrderItem it : o.OrderItems) {
            Decimal remaining = nz(it.NFT_Qty_Confirmed__c) - nz(it.NFT_Qty_Shipped__c);
            if (remaining <= 0) { continue; }
            Decimal units = mode == 'One unit per line' ? Math.min((Decimal) 1, remaining) : remaining;
            NFT_Inventory_Balance__c b = bal.get(it.Product2Id);
            if (b != null) { units = Math.min(units, Math.max((Decimal) 0, nz(b.NFT_Qty_On_Hand__c))); }
            if (units <= 0) { continue; }
            it.NFT_Qty_Shipped__c = nz(it.NFT_Qty_Shipped__c) + units;
            changed.add(it);
            totalUnits += units;
            parts.add(it.Product2.Name);
            if (b != null) {
                b.NFT_Qty_On_Hand__c = nz(b.NFT_Qty_On_Hand__c) - units;
                b.NFT_Qty_Reserved__c = Math.max((Decimal) 0, nz(b.NFT_Qty_Reserved__c) - units);
                b.NFT_Last_Updated_At__c = Datetime.now();
            }
        }
        if (totalUnits == 0) {
            return new Result('Nothing can ship: no confirmed units left, or no stock on hand at ' + location + '.', o.Id);
        }

        NFT_Shipment__c s = new NFT_Shipment__c(
            Name = nextName('SHP-', 'NFT_Shipment__c'), NFT_Order__c = o.Id, NFT_Account__c = o.AccountId,
            NFT_Provider__c = o.NFT_Fulfillment_Provider__c, NFT_Carrier__c = useCarrier,
            NFT_Tracking_Number__c = trackingFor(useCarrier), NFT_Status__c = 'In Transit', NFT_Units__c = totalUnits,
            NFT_Contents__c = (String.valueOf(totalUnits.intValue()) + (totalUnits == 1 ? ' unit · ' : ' units · ') + String.join(parts, ', ')).left(120),
            NFT_Shipped_At__c = Datetime.now(), NFT_Expected_Delivery__c = Date.today().addDays(3));
        insert s;
        update changed;
        update bal.values();

        Boolean allShipped = true;
        for (OrderItem it : o.OrderItems) { if (nz(it.NFT_Qty_Shipped__c) < it.Quantity) { allShipped = false; } }
        update new Order(Id = o.Id,
            NFT_Fulfillment_Status__c = allShipped ? 'Shipped' : 'Partially Shipped',
            NFT_First_Shipped_At__c = o.NFT_First_Shipped_At__c == null ? Datetime.now() : o.NFT_First_Shipped_At__c);

        List<NFT_Shipment__c> all = [SELECT Id FROM NFT_Shipment__c WHERE NFT_Order__c = :o.Id ORDER BY NFT_Shipped_At__c, Name];
        for (Integer i = 0; i < all.size(); i++) { all[i].NFT_Sequence__c = String.valueOf(i + 1) + ' of ' + String.valueOf(all.size()); }
        update all;

        insert NFT_SyncLogger.build(o.Id, o.NFT_External_Order_Id__c, 'ShipStation', 'Label and tracking', 'Success',
            'Shipment ' + s.Name + ' created, ' + useCarrier + '.');
        return new Result('Shipment ' + s.Name + ' created: ' + String.valueOf(totalUnits.intValue()) + ' unit(s) by ' + useCarrier + '.', s.Id);
    }

    // ------------------------------------------------------------------ deliver
    public static Result deliver(Id orderId) {
        Order o = loadOrder(orderId);
        List<NFT_Shipment__c> open = [SELECT Id, Name FROM NFT_Shipment__c WHERE NFT_Order__c = :o.Id AND NFT_Status__c != 'Delivered'];
        if (open.isEmpty()) { return new Result('No shipments are waiting for delivery.', o.Id); }
        List<NFT_Sync_Log__c> logs = new List<NFT_Sync_Log__c>();
        for (NFT_Shipment__c s : open) {
            s.NFT_Status__c = 'Delivered';
            s.NFT_Delivered_At__c = Datetime.now();
            logs.add(NFT_SyncLogger.build(o.Id, o.NFT_External_Order_Id__c, 'ShipStation', 'Shipment delivered', 'Success', 'Shipment ' + s.Name + ' delivered.'));
        }
        update open;
        Boolean allShipped = true;
        for (OrderItem it : o.OrderItems) { if (nz(it.NFT_Qty_Shipped__c) < it.Quantity) { allShipped = false; } }
        if (allShipped) {
            update new Order(Id = o.Id, NFT_Fulfillment_Status__c = 'Delivered', NFT_Delivered_At__c = Datetime.now());
        }
        insert logs;
        return new Result(String.valueOf(open.size()) + ' shipment(s) delivered' + (allShipped ? '. Order is Delivered.' : '. Units are still waiting to ship.'), o.Id);
    }

    // ------------------------------------------------------------------ invoice
    public static Result postInvoice(Id orderId) {
        Order o = loadOrder(orderId);
        Decimal amount = 0;
        List<OrderItem> changed = new List<OrderItem>();
        for (OrderItem it : o.OrderItems) {
            Decimal open = nz(it.NFT_Qty_Shipped__c) - nz(it.NFT_Qty_Invoiced__c);
            if (open > 0) {
                amount += open * it.UnitPrice;
                it.NFT_Qty_Invoiced__c = it.NFT_Qty_Shipped__c;
                changed.add(it);
            }
        }
        if (changed.isEmpty()) { return new Result('Every shipped unit is already invoiced.', o.Id); }
        String ref = 'AS-BIL-' + pad([SELECT COUNT() FROM NFT_Invoice__c] + 200, 5);
        while ([SELECT COUNT() FROM NFT_Invoice__c WHERE NFT_Accounting_Seed_Ref__c = :ref] > 0) { ref = 'AS-BIL-' + digits(5); }
        NFT_Invoice__c inv = new NFT_Invoice__c(
            Name = nextName('INV-', 'NFT_Invoice__c'), NFT_Order__c = o.Id, NFT_Account__c = o.AccountId,
            NFT_Invoice_Date__c = Date.today(), NFT_Amount__c = amount, NFT_Status__c = 'Posted', NFT_Accounting_Seed_Ref__c = ref);
        insert inv;
        update changed;
        update new Order(Id = o.Id, NFT_Accounting_Status__c = 'Posted');
        insert NFT_SyncLogger.build(o.Id, o.NFT_External_Order_Id__c, 'Accounting Seed', 'Invoice post (simulated)', 'Success',
            'Invoice ' + inv.Name + ' posted.');
        return new Result('Invoice ' + inv.Name + ' posted for $' + amount.setScale(2) + ' (simulated).', inv.Id);
    }

    // ------------------------------------------------------------------ retry
    public static Result retry(Id logId) {
        List<NFT_Sync_Log__c> failed = logId == null
            ? [SELECT Id, NFT_Order__c, NFT_Record_Ref__c, NFT_System__c, NFT_Event__c, NFT_Message__c, NFT_Attempts__c FROM NFT_Sync_Log__c WHERE NFT_Status__c = 'Failed' LIMIT 200]
            : [SELECT Id, NFT_Order__c, NFT_Record_Ref__c, NFT_System__c, NFT_Event__c, NFT_Message__c, NFT_Attempts__c FROM NFT_Sync_Log__c WHERE Id = :logId AND NFT_Status__c = 'Failed'];
        if (failed.isEmpty()) { return new Result('No failed syncs to retry.', logId); }
        List<NFT_Sync_Log__c> fresh = new List<NFT_Sync_Log__c>();
        for (NFT_Sync_Log__c l : failed) {
            l.NFT_Attempts__c = nz(l.NFT_Attempts__c) + 1;
            l.NFT_Status__c = 'Retried';
            l.NFT_Message__c = ((l.NFT_Message__c == null ? '' : l.NFT_Message__c) + ' Retried successfully (simulated).').left(255);
            fresh.add(NFT_SyncLogger.build(l.NFT_Order__c, l.NFT_Record_Ref__c, l.NFT_System__c, l.NFT_Event__c, 'Success', 'Retry succeeded (simulated).'));
        }
        update failed;
        insert fresh;
        return new Result(String.valueOf(failed.size()) + ' sync(s) retried successfully (simulated).', logId);
    }

    // ------------------------------------------------------------------ FBA sync
    public static Result fbaSync(Id productId) {
        List<NFT_Inventory_Balance__c> rows = [SELECT Id, NFT_Product__r.NFT_SKU__c FROM NFT_Inventory_Balance__c
                                               WHERE NFT_Product__c = :productId AND NFT_Location__c = 'Amazon FBA' LIMIT 1];
        if (rows.isEmpty()) { return new Result('This product has no Amazon FBA balance.', productId); }
        rows[0].NFT_Last_Updated_At__c = Datetime.now();
        update rows;
        insert NFT_SyncLogger.build(null, rows[0].NFT_Product__r.NFT_SKU__c, 'Amazon FBA', 'Inventory sync', 'Success',
            'FBA quantities confirmed for ' + rows[0].NFT_Product__r.NFT_SKU__c + '.');
        return new Result('FBA inventory synced for ' + rows[0].NFT_Product__r.NFT_SKU__c + ' (simulated).', productId);
    }
}
