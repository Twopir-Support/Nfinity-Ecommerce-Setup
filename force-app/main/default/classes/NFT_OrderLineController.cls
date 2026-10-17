/**
 * NFT demo: order lines for the nftOrderLineStatus LWC.
 */
public with sharing class NFT_OrderLineController {
    @AuraEnabled(cacheable=true)
    public static List<OrderItem> getLines(Id orderId) {
        return [SELECT Id, NFT_Line_No__c, Product2Id, Product2.Name, Product2.ProductCode, Quantity,
                       NFT_Qty_Confirmed__c, NFT_Qty_Shipped__c, NFT_Qty_Invoiced__c, NFT_Line_Status__c, NFT_Short_Shipped__c
                FROM OrderItem WHERE OrderId = :orderId WITH USER_MODE ORDER BY NFT_Line_No__c];
    }
}
