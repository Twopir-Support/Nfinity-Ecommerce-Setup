trigger NFT_InventoryBalanceTrigger on NFT_Inventory_Balance__c (after insert, after update, after delete, after undelete) {
    Set<Id> productIds = new Set<Id>();
    for (NFT_Inventory_Balance__c b : (Trigger.isDelete ? Trigger.old : Trigger.new)) {
        productIds.add(b.NFT_Product__c);
        if (Trigger.isUpdate) { productIds.add(Trigger.oldMap.get(b.Id).NFT_Product__c); }
    }
    NFT_TriggerHandler.recalcProducts(productIds);
}
