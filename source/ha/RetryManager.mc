import Toybox.Lang;

// Wraps one request with a bounded reissue loop: every failure reason is
// retried, and nothing classifies them — the retry itself is the test, since
// *would this kind recover* is a guess we would otherwise have to maintain a
// table for. The cost is that an auth failure or a template error burns the
// full threshold before it surfaces, which is why it is kept small.
//
// Carries the wrapped request's identity, so a spent threshold surfaces as a
// RequestError rather than a bare reason. Re-registration is the one place two
// request types interleave, and a failure there stays :registration: a bad
// request against our registration body means our own body is malformed, while
// the same code on a fetch means a template error on the Home Assistant side.
class RetryManager {
    private const REQUEST_RETRIES = 3;

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
    private var _target as Symbol or Null;
    private var _attemptsLeft as Number;
    private var _hasReregistered as Boolean;

    function initialize(client as HaClient, request as Method, callback as Method,
                        requestType as Symbol, target as Symbol or Null) {
        _client = client;
        _request = request;
        _callback = callback;
        _requestType = requestType;
        _target = target;
        _attemptsLeft = REQUEST_RETRIES;
        _hasReregistered = false;
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
            // Bounded to one re-registration cycle per request: a webhook id
            // that is invalid again right after a fresh registration is a
            // Home Assistant-side condition this loop cannot fix by
            // repeating itself, so it surfaces rather than falling through
            // to the generic reissue below.
            if (_hasReregistered) {
                surface(reason, _requestType, _target);
                return;
            }

            _hasReregistered = true;
            Webhook.clearId();
            _client.register(method(:onRegistered));
            return;
        }

        if (_attemptsLeft <= 0) {
            surface(reason, _requestType, _target);
            return;
        }

        _attemptsLeft--;
        _request.invoke(method(:onAttempt));
    }

    function onRegistered(webhookId as String or Null, reason as Object or Null) as Void {
        if (reason != null) {
            surface(reason, :registration, null);
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

    private function surface(reason as Object, requestType as Symbol, target as Symbol or Null) as Void {
        _callback.invoke(null, new RequestError(reason, requestType, target));
    }
}
