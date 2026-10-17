/**
 * NFT demo: invocable action called by a screen flow. Simulates ShipMonk or FBA confirming an order.
 */
public with sharing class NFT_ConfirmOrderAction {
    public class Request {
        @InvocableVariable(label='Order Id', required=true) public Id orderId;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Simulate 3PL Confirm' description='Simulates ShipMonk or FBA confirming an order.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.confirm(r.orderId);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
