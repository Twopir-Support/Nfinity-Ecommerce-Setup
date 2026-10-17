/**
 * NFT demo: invocable action called by a screen flow. Marks open shipments delivered.
 */
public with sharing class NFT_DeliverOrderAction {
    public class Request {
        @InvocableVariable(label='Order Id', required=true) public Id orderId;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Simulate Deliver' description='Marks open shipments delivered.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.deliver(r.orderId);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
