import Toybox.Communications;
import Toybox.Lang;

// A post the webhook may refuse, because the id it was issued for can go stale
// on the Home Assistant side at any time. Registering earns a fresh id and the
// post goes out behind it once; an id refused the moment it was issued is the
// request's own failure, left to whatever budget the request is running on.
class WebhookPost {
    private var _client as HaClient;
    private var _body as Dictionary;
    private var _responseType as Symbol;
    private var _responseContentType as Communications.HttpResponseContentType;
    private var _callback as Method or Null;
    private var _registered as Boolean;

    function initialize(client as HaClient, body as Dictionary, responseType as Symbol,
                        responseContentType as Communications.HttpResponseContentType) {
        _client = client;
        _body = body;
        _responseType = responseType;
        _responseContentType = responseContentType;
        _callback = null;
        _registered = false;
    }

    function attempt(callback as Method) as Void {
        _callback = callback;
        post();
    }

    function onPosted(result as Object or Null, reason as Object or Null) as Void {
        if (reason != RequestError.UNUSABLE_WEBHOOK || _registered) {
            (_callback as Method).invoke(result, reason);
            return;
        }

        _registered = true;
        _client.register(method(:onRegistered));
    }

    function onRegistered(webhookId as String or Null, error as RequestError or Null) as Void {
        if (error != null) {
            (_callback as Method).invoke(null, error);
            return;
        }

        post();
    }

    private function post() as Void {
        _client.postToWebhook(_body, method(:onPosted), _responseType, _responseContentType);
    }
}
