trigger NFT_OrderItemTrigger on OrderItem (before insert, after insert, after update, after delete) {
    if (Trigger.isBefore) { NFT_TriggerHandler.defaultPricebookEntries(Trigger.new); return; }
    Set<Id> orderIds = new Set<Id>();
    for (OrderItem i : (Trigger.isDelete ? Trigger.old : Trigger.new)) { orderIds.add(i.OrderId); }
    NFT_TriggerHandler.recalcAccountsForOrders(orderIds);
}
