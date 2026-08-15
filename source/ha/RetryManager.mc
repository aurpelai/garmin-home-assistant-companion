import Toybox.Lang;

// Every failure reason is retried and none is classified: the retry itself is
// the test, where *would this kind recover* would be a guess needing a table to
// maintain. The cost is that an auth failure burns the full threshold before it
// surfaces, which is why the threshold is small.
//
// Re-registration is the one place two request types interleave, and a failure
// there keeps the registration type rather than inheriting the caller's.
class RetryManager {
    private const REQUEST_RETRIES = 3;
    private const REGISTRATION_RETRIES = 1;

    // A dead webhook_id shows up as one of these: -400 because HA sends no body
    // (Connect IQ reports that as invalid-http-body), or 404 when the id is gone.
    private const INVALID_WEBHOOK_CODES = [
        Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE,
        404
    ];

    private var _client as HaClient;
    private var _request as Method;
    private var _callback as Method;
    private var _requestType as Symbol;
    private var _attemptsLeft as Number;
    private var _registrationsLeft as Number;

    function initialize(client as HaClient, request as Method, callback as Method,
                        requestType as Symbol) {
        _client = client;
        _request = request;
        _callback = callback;
        _requestType = requestType;
        _attemptsLeft = REQUEST_RETRIES;
        _registrationsLeft = REGISTRATION_RETRIES;
    }

    function attempt() as Void {
        _request.invoke(method(:onAttempt));
    }

    function onAttempt(result as Object or Null, reason as Object or Null) as Void {
        if (reason == null) {
            _callback.invoke(result, null);
            return;
        }

        if (reason instanceof Number && isInvalidWebhookCode(reason)) {
            // A webhook id that is invalid again after REGISTRATION_RETRIES
            // fresh registrations is a Home Assistant-side condition this loop
            // cannot fix by repeating itself, so it surfaces rather than
            // falling through to the generic reissue below.
            if (_registrationsLeft <= 0) {
                surface(reason, _requestType);
                return;
            }

            _registrationsLeft--;
            Webhook.clearId();
            _client.register(method(:onRegistered));
            return;
        }

        if (_attemptsLeft <= 0) {
            surface(reason, _requestType);
            return;
        }

        _attemptsLeft--;
        _request.invoke(method(:onAttempt));
    }

    function onRegistered(webhookId as String or Null, reason as Object or Null) as Void {
        if (reason != null) {
            surface(reason, RequestType.REGISTRATION);
            return;
        }

        // The reissued request is fresh and carries its own budget: registering
        // recovered, so the original failure counted for nothing.
        _attemptsLeft = REQUEST_RETRIES;
        _request.invoke(method(:onAttempt));
    }

    function isInvalidWebhookCode(code as Number) as Boolean {
        for (var index = 0; index < INVALID_WEBHOOK_CODES.size(); index++) {
            if (INVALID_WEBHOOK_CODES[index] == code) {
                return true;
            }
        }
        return false;
    }

    private function surface(reason as Object, requestType as Symbol) as Void {
        _callback.invoke(null, new RequestError(reason, requestType));
    }
}
