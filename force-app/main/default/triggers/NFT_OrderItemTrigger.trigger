trigger NFT_OrderItemTrigger on OrderItem (after insert, after update, after delete) {
    Set<Id> orderIds = new Set<Id>();
    for (OrderItem i : (Trigger.isDelete ? Trigger.old : Trigger.new)) { orderIds.add(i.OrderId); }
    NFT_TriggerHandler.recalcAccountsForOrders(orderIds);
}
