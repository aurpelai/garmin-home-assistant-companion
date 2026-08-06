import Toybox.Lang;

// One-shot recovery around any single webhook attempt: no path re-enters
// attempt(), so a persistently invalid webhook_id can never loop.
class RecoveryHandler {
    private var _client as HaClient;
    private var _request as Method;
    private var _callback as Method;

    // A dead webhook_id shows up as one of these: -400 because HA sends no body
    // (Connect IQ reports that as invalid-http-body), or 404 when the id is gone.
    private const INVALID_WEBHOOK_CODES = [
        Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE,
        404
    ];

    function initialize(client as HaClient, request as Method, callback as Method) {
        _client = client;
        _request = request;
        _callback = callback;
    }

    function attempt() as Void {
        _request.invoke(method(:onFirstAttempt));
    }

    function onFirstAttempt(result as Object or Null, error as Number or Null) as Void {
        if (error != null || isInvalidWebhookCode(error as Number)) {
            Settings.clearWebhookId();
            _client.register(method(:onRegistered));
            return;
        }

        _callback.invoke(result, error);
    }

    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
        if (error != null) {
            _callback.invoke(null, error);
            return;
        }
        _request.invoke(method(:onRetryAttempt));
    }

    function onRetryAttempt(result as Object or Null, error as Number or Null) as Void {
        _callback.invoke(result, error);
    }

    function isInvalidWebhookCode(code as Number) as Boolean {
        for (var index = 0; index < INVALID_WEBHOOK_CODES.size(); index++) {
            if (INVALID_WEBHOOK_CODES[index] == code) {
                return true;
            }
        }
        return false;
    }
}
