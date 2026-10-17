/**
 * NFT demo: invocable action called by a screen flow. Simulates an Amazon FBA inventory sync for one product.
 */
public with sharing class NFT_FbaSyncAction {
    public class Request {
        @InvocableVariable(label='Product Id') public Id productId;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Simulate FBA Inventory Sync' description='Simulates an Amazon FBA inventory sync for one product.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.fbaSync(r.productId);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
