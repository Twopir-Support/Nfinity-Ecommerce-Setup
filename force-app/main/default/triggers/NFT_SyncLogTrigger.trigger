trigger NFT_SyncLogTrigger on NFT_Sync_Log__c (after insert, after update, after delete, after undelete) {
    Set<Id> orderIds = new Set<Id>();
    for (NFT_Sync_Log__c l : (Trigger.isDelete ? Trigger.old : Trigger.new)) {
        orderIds.add(l.NFT_Order__c);
        if (Trigger.isUpdate) { orderIds.add(Trigger.oldMap.get(l.Id).NFT_Order__c); }
    }
    NFT_TriggerHandler.recalcFailedSyncs(orderIds);
}
