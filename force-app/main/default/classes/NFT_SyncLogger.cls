/**
 * NFT demo: builds NFT_Sync_Log__c rows. Every simulated system message is one row.
 */
public with sharing class NFT_SyncLogger {
    public static NFT_Sync_Log__c build(Id orderId, String recordRef, String systemName, String eventName, String status, String message) {
        String stamp = String.valueOf(Datetime.now().getTime()) + '-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
        return new NFT_Sync_Log__c(
            NFT_Order__c = orderId,
            NFT_Record_Ref__c = recordRef == null ? null : recordRef.left(60),
            NFT_System__c = systemName,
            NFT_Event__c = eventName == null ? null : eventName.left(80),
            NFT_Status__c = status,
            NFT_Message__c = message == null ? null : message.left(255),
            NFT_Logged_At__c = Datetime.now(),
            NFT_Attempts__c = 1,
            NFT_External_Event_Id__c = ('NFT-' + systemName + '-' + stamp).replace(' ', '').left(80)
        );
    }
}
