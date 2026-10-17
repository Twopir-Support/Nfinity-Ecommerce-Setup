@IsTest
private class NFT_CommerceTests {

    @TestSetup
    static void setup() {
        Id pb = Test.getStandardPricebookId();
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Apex Cheer Shoe – White – 7', ProductCode = 'APEX-WHT-07', NFT_SKU__c = 'APEX-WHT-07', IsActive = true),
            new Product2(Name = 'Shimmer Backpack – Teal', ProductCode = 'SHBP-TEA-OS', NFT_SKU__c = 'SHBP-TEA-OS', IsActive = true)
        };
        insert products;
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = pb, Product2Id = products[0].Id, UnitPrice = 129.99, IsActive = true),
            new PricebookEntry(Pricebook2Id = pb, Product2Id = products[1].Id, UnitPrice = 109.99, IsActive = true)
        };
        insert new List<Account>{
            new Account(Name = 'Test Shopper', NFT_Customer_Key__c = 'SC-TEST-1', NFT_Customer_Source__c = 'Shopify'),
            new Account(Name = 'Amazon Customer (Masked)', NFT_Customer_Key__c = 'AMZ-MASKED', NFT_Customer_Source__c = 'Amazon')
        };
        List<NFT_Inventory_Balance__c> bal = new List<NFT_Inventory_Balance__c>();
        for (Product2 p : products) {
            bal.add(new NFT_Inventory_Balance__c(Name = p.NFT_SKU__c + ' SM', NFT_Product__c = p.Id, NFT_Location__c = 'ShipMonk Warehouse',
                NFT_Unique_Key__c = p.NFT_SKU__c + '-SM', NFT_Qty_On_Hand__c = 10, NFT_Qty_Reserved__c = 0, NFT_Reorder_Point__c = 2));
            bal.add(new NFT_Inventory_Balance__c(Name = p.NFT_SKU__c + ' FBA', NFT_Product__c = p.Id, NFT_Location__c = 'Amazon FBA',
                NFT_Unique_Key__c = p.NFT_SKU__c + '-FBA', NFT_Qty_On_Hand__c = 10, NFT_Qty_Reserved__c = 0, NFT_Reorder_Point__c = 2));
        }
        insert bal;
    }

    private static NFT_CommerceService.Result newShopifyOrder(String ext) {
        return NFT_CommerceService.createOrder('Shopify', null, 'SC-TEST-1',
            new List<String>{ 'APEX-WHT-07', 'SHBP-TEA-OS' }, new List<Decimal>{ 2, 1 }, ext, false);
    }

    @IsTest
    static void fullLifecycle() {
        Test.startTest();
        NFT_CommerceService.Result r = newShopifyOrder('SHP-T1');
        Id orderId = r.recordId;
        NFT_CommerceService.confirm(orderId);
        NFT_CommerceService.ship(orderId, 'UPS Ground', 'One unit per line');
        NFT_CommerceService.postInvoice(orderId);
        NFT_CommerceService.ship(orderId, 'USPS Priority', 'Ship all remaining units');
        NFT_CommerceService.deliver(orderId);
        Test.stopTest();

        Order o = [SELECT NFT_Fulfillment_Status__c, NFT_Units_Shipped__c, NFT_Units_Invoiced__c, NFT_Accounting_Status__c, Status FROM Order WHERE Id = :orderId];
        System.assertEquals('Delivered', o.NFT_Fulfillment_Status__c);
        System.assertEquals(3, o.NFT_Units_Shipped__c);
        System.assertEquals(2, o.NFT_Units_Invoiced__c);
        System.assertEquals('Draft', o.Status, 'Orders must stay Draft');
        System.assertEquals(2, [SELECT COUNT() FROM NFT_Shipment__c WHERE NFT_Order__c = :orderId]);
        NFT_Inventory_Balance__c b = [SELECT NFT_Qty_On_Hand__c, NFT_Qty_Reserved__c FROM NFT_Inventory_Balance__c WHERE NFT_Unique_Key__c = 'APEX-WHT-07-SM'];
        System.assertEquals(8, b.NFT_Qty_On_Hand__c);
        System.assertEquals(0, b.NFT_Qty_Reserved__c);
        Account a = [SELECT NFT_Total_Orders__c, NFT_Open_Orders__c FROM Account WHERE NFT_Customer_Key__c = 'SC-TEST-1'];
        System.assertEquals(1, a.NFT_Total_Orders__c);
        System.assertEquals(0, a.NFT_Open_Orders__c);
    }

    @IsTest
    static void duplicateIsBlocked() {
        newShopifyOrder('SHP-T2');
        Test.startTest();
        NFT_CommerceService.Result dup = newShopifyOrder('SHP-T2');
        Test.stopTest();
        System.assert(dup.message.startsWith('Duplicate blocked'), dup.message);
        System.assertEquals(1, [SELECT COUNT() FROM Order WHERE NFT_External_Order_Id__c = 'SHP-T2']);
        System.assertEquals(1, [SELECT COUNT() FROM NFT_Sync_Log__c WHERE NFT_Status__c = 'Duplicate Blocked']);
        NFT_Inventory_Balance__c b = [SELECT NFT_Qty_Reserved__c FROM NFT_Inventory_Balance__c WHERE NFT_Unique_Key__c = 'APEX-WHT-07-SM'];
        System.assertEquals(2, b.NFT_Qty_Reserved__c, 'Duplicate must not reserve again');
    }

    @IsTest
    static void amazonOrderReservesAtFba() {
        Test.startTest();
        NFT_CommerceService.Result r = NFT_CommerceService.createOrder('Amazon', null, null,
            new List<String>{ 'APEX-WHT-07' }, new List<Decimal>{ 1 }, null, false);
        Test.stopTest();
        Order o = [SELECT NFT_Fulfillment_Provider__c, NFT_External_Order_Id__c FROM Order WHERE Id = :r.recordId];
        System.assertEquals('Amazon FBA', o.NFT_Fulfillment_Provider__c);
        System.assertEquals(1, [SELECT NFT_Qty_Reserved__c FROM NFT_Inventory_Balance__c WHERE NFT_Unique_Key__c = 'APEX-WHT-07-FBA'].NFT_Qty_Reserved__c);
    }

    @IsTest
    static void retryAndFbaSyncAndActions() {
        NFT_CommerceService.Result r = newShopifyOrder('SHP-T3');
        insert NFT_SyncLogger.build(r.recordId, 'SHP-T3', 'ShipStation', 'Tracking update', 'Failed', 'Timeout');
        System.assertEquals(1, [SELECT NFT_Failed_Sync_Count__c FROM Order WHERE Id = :r.recordId].NFT_Failed_Sync_Count__c);

        Test.startTest();
        NFT_RetrySyncAction.Request rr = new NFT_RetrySyncAction.Request();
        NFT_RetrySyncAction.run(new List<NFT_RetrySyncAction.Request>{ rr });
        Product2 p = [SELECT Id FROM Product2 WHERE NFT_SKU__c = 'APEX-WHT-07'];
        NFT_FbaSyncAction.Request fr = new NFT_FbaSyncAction.Request();
        fr.productId = p.Id;
        NFT_FbaSyncAction.run(new List<NFT_FbaSyncAction.Request>{ fr });
        NFT_ConfirmOrderAction.Request cr = new NFT_ConfirmOrderAction.Request();
        cr.orderId = r.recordId;
        NFT_ConfirmOrderAction.run(new List<NFT_ConfirmOrderAction.Request>{ cr });
        NFT_ShipOrderAction.Request sr = new NFT_ShipOrderAction.Request();
        sr.orderId = r.recordId; sr.carrier = 'FedEx Ground'; sr.mode = 'Ship all remaining units';
        NFT_ShipOrderAction.run(new List<NFT_ShipOrderAction.Request>{ sr });
        NFT_PostInvoiceAction.Request ir = new NFT_PostInvoiceAction.Request();
        ir.orderId = r.recordId;
        NFT_PostInvoiceAction.run(new List<NFT_PostInvoiceAction.Request>{ ir });
        NFT_DeliverOrderAction.Request dr = new NFT_DeliverOrderAction.Request();
        dr.orderId = r.recordId;
        NFT_DeliverOrderAction.run(new List<NFT_DeliverOrderAction.Request>{ dr });
        NFT_SimulateOrderAction.Request nr = new NFT_SimulateOrderAction.Request();
        nr.channel = 'Shopify'; nr.customerKey = 'SC-TEST-1'; nr.sku1 = 'SHBP-TEA-OS'; nr.qty1 = 1; nr.resend = true;
        NFT_SimulateOrderAction.run(new List<NFT_SimulateOrderAction.Request>{ nr });
        Test.stopTest();

        System.assertEquals(0, [SELECT NFT_Failed_Sync_Count__c FROM Order WHERE Id = :r.recordId].NFT_Failed_Sync_Count__c);
        System.assertEquals(1, [SELECT COUNT() FROM NFT_Invoice__c WHERE NFT_Order__c = :r.recordId]);
        System.assertEquals(2, NFT_OrderLineController.getLines(r.recordId).size());
        Product2 totals = [SELECT NFT_Total_On_Hand__c FROM Product2 WHERE Id = :p.Id];
        System.assertEquals(18, totals.NFT_Total_On_Hand__c);
    }

    @IsTest
    static void guards() {
        NFT_CommerceService.Result r = newShopifyOrder('SHP-T4');
        Test.startTest();
        System.assert(NFT_CommerceService.ship(r.recordId, 'UPS Ground', null).message.startsWith('Only Confirmed'));
        System.assert(NFT_CommerceService.postInvoice(r.recordId).message.startsWith('Every shipped'));
        System.assert(NFT_CommerceService.deliver(r.recordId).message.startsWith('No shipments'));
        NFT_CommerceService.confirm(r.recordId);
        System.assert(NFT_CommerceService.confirm(r.recordId).message.contains('already'));
        System.assert(NFT_CommerceService.retry(null).message.startsWith('No failed'));
        Boolean threw = false;
        try { NFT_CommerceService.createOrder('Shopify', null, 'SC-TEST-1', new List<String>{ 'NOPE' }, new List<Decimal>{ 1 }, 'SHP-T5', false); }
        catch (NFT_Exception e) { threw = true; }
        Test.stopTest();
        System.assert(threw, 'Unknown SKU must throw');
    }

    @IsTest
    static void importedOrderGetsStandardPricebook() {
        Product2 p = new Product2(Name = 'Nova Cheer Shoe – Black – 6', ProductCode = 'NOVA-BLK-06', NFT_SKU__c = 'NOVA-BLK-06', IsActive = true);
        insert p;
        Account a = [SELECT Id FROM Account WHERE NFT_Customer_Key__c = 'SC-TEST-1'];
        Test.startTest();
        Order o = new Order(AccountId = a.Id, EffectiveDate = Date.today(), Status = 'Draft', NFT_External_Order_Id__c = 'SHP-T6');
        insert o;
        insert new OrderItem(OrderId = o.Id, Product2Id = p.Id, Quantity = 2, UnitPrice = 99.99);
        Test.stopTest();
        System.assertEquals(Test.getStandardPricebookId(), [SELECT Pricebook2Id FROM Order WHERE Id = :o.Id].Pricebook2Id);
        System.assertEquals(99.99, [SELECT UnitPrice FROM PricebookEntry WHERE Product2Id = :p.Id].UnitPrice);
        System.assertEquals(199.98, [SELECT TotalAmount FROM Order WHERE Id = :o.Id].TotalAmount);
    }
}
