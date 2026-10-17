/**
 * NFT demo: invocable action called by a screen flow. Simulates a ShipStation shipment with carrier and tracking.
 */
public with sharing class NFT_ShipOrderAction {
    public class Request {
        @InvocableVariable(label='Order Id') public Id orderId;
        @InvocableVariable(label='Carrier') public String carrier;
        @InvocableVariable(label='Ship mode') public String mode;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Simulate Ship' description='Simulates a ShipStation shipment with carrier and tracking.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.ship(r.orderId, r.carrier, r.mode);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
