import Toybox.Communications;
import Toybox.Lang;

// Home Assistant can retire a webhook id at any time, so registering again is
// part of making the request rather than a failure to report. An id refused the
// moment it was issued is the request's own failure and surfaces as one.
class WebhookRequest {
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

    function onPosted(result as Object or Null, error as RequestError or Null) as Void {
        if (error == null || error.reason != RequestError.UNUSABLE_WEBHOOK || _registered) {
            (_callback as Method).invoke(result, error);
            return;
        }

        _registered = true;
        _client.registerWithHomeAssistant(method(:onRegistered));
    }

    function onRegistered(webhookId as String or Null, error as RequestError or Null) as Void {
        if (error != null) {
            (_callback as Method).invoke(null, error);
            return;
        }

        post();
    }

    function attempt(callback as Method) as Void {
        _callback = callback;
        post();
    }

    private function post() as Void {
        _client.attemptRequest(_body, method(:onPosted), _responseType, _responseContentType);
    }
}
