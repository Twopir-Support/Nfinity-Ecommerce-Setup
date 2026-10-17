/**
 * NFT demo: invocable action called by a screen flow. Creates a simulated Shopify or Amazon order and reserves stock.
 */
public with sharing class NFT_SimulateOrderAction {
    public class Request {
        @InvocableVariable(label='Channel (Shopify or Amazon)', required=true) public String channel;
        @InvocableVariable(label='Account Id') public Id accountId;
        @InvocableVariable(label='Customer Key') public String customerKey;
        @InvocableVariable(label='SKU 1') public String sku1;
        @InvocableVariable(label='Quantity 1') public Decimal qty1;
        @InvocableVariable(label='SKU 2') public String sku2;
        @InvocableVariable(label='Quantity 2') public Decimal qty2;
        @InvocableVariable(label='SKU 3') public String sku3;
        @InvocableVariable(label='Quantity 3') public Decimal qty3;
        @InvocableVariable(label='External Order ID') public String externalOrderId;
        @InvocableVariable(label='Resend last order') public Boolean resend;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Simulate New Order' description='Creates a simulated Shopify or Amazon order and reserves stock.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.createOrder(r.channel, r.accountId, r.customerKey, new List<String>{ r.sku1, r.sku2, r.sku3 }, new List<Decimal>{ r.qty1, r.qty2, r.qty3 }, r.externalOrderId, r.resend);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
