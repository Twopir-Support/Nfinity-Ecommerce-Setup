trigger NFT_OrderTrigger on Order (before insert, after insert, after update, after delete) {
    if (Trigger.isBefore) { NFT_TriggerHandler.defaultPricebook(Trigger.new); return; }
    Set<Id> accountIds = new Set<Id>();
    List<Order> rows = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (Order o : rows) {
        if (o.NFT_External_Order_Id__c == null) { continue; }
        accountIds.add(o.AccountId);
        if (Trigger.isUpdate) { accountIds.add(Trigger.oldMap.get(o.Id).AccountId); }
    }
    NFT_TriggerHandler.recalcAccounts(accountIds);
}
