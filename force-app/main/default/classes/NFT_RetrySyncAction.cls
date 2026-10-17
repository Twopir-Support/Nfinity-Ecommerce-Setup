/**
 * NFT demo: invocable action called by a screen flow. Retries one failed sync log, or all failed logs when no Id is given.
 */
public with sharing class NFT_RetrySyncAction {
    public class Request {
        @InvocableVariable(label='Sync Log Id') public Id logId;
    }
    public class Response {
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Record Id') public Id recordId;
    }
    @InvocableMethod(label='NFT Retry Failed Sync' description='Retries one failed sync log, or all failed logs when no Id is given.' category='NFT Demo')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            NFT_CommerceService.Result res = NFT_CommerceService.retry(r.logId);
            Response resp = new Response();
            resp.message = res.message;
            resp.recordId = res.recordId;
            out.add(resp);
        }
        return out;
    }
}
