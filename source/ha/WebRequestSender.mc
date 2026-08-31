import Toybox.Communications;
import Toybox.Lang;

// The only object that touches Communications. HaClient owns when to send; this
// owns how a POST reaches Home Assistant.
//
// No response type is declared: the system then parses by the response's own
// Content-Type, which keeps the HTTP status intact — declaring one makes an
// auth rejection arrive as an invalid-body error rather than a 401. A dead
// webhook's empty 200 carries no Content-Type at all and still arrives as a
// 200 with a null body, so the re-registration path is unaffected (verified
// against a live instance on 2026-08-26).
class WebRequestSender {
    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + Settings.getToken(),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            }
        };

        Communications.makeWebRequest(
            Settings.getBaseUrl() + path,
            body as Dictionary<Object, Object>,
            options,
            handler.method(:onResponse)
        );
    }

    // UNVERIFIED: Connect IQ still delivers a cancelled request's reply, so the
    // caller nulls its callbacks to drop it.
    function cancelAll() as Void {
        Communications.cancelAllRequests();
    }
}
