// NFT demo: removes demo orders, lines, shipments, invoices and sync logs so the load can run again.
// Catalog (products, accounts, balances) is kept; the load scripts upsert it back to the demo values.
delete [SELECT Id FROM NFT_Sync_Log__c LIMIT 9000];
delete [SELECT Id FROM NFT_Invoice__c LIMIT 9000];
delete [SELECT Id FROM NFT_Shipment__c LIMIT 9000];
delete [SELECT Id FROM OrderItem WHERE Order.NFT_External_Order_Id__c != null LIMIT 9000];
delete [SELECT Id FROM Order WHERE NFT_External_Order_Id__c != null LIMIT 9000];
