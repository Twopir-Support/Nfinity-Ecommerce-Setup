/**
 * NFT demo: invocable action called by a screen flow. Simulates an Accounting Seed invoice for shipped units.
 */
public with sharing class NFT_PostInvoiceAction {
    public class Request {
        @InvocableVariable(label='Order Id') public Id orderId;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Simulate Post Invoice' description='Simulates an Accounting Seed invoice for shipped units.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.postInvoice(r.orderId);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
