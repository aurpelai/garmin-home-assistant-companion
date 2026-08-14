import Toybox.Lang;

// Wraps one request with a bounded reissue loop: every failure reason is
// retried, and nothing classifies them — the retry itself is the test, since
// *would this kind recover* is a guess we would otherwise have to maintain a
// table for. The cost is that an auth failure or a template error burns the
// full threshold before it surfaces, which is why it is kept small.
class RetryManager {
    // Placeholder pending real-instance evidence: small enough that a
    // deterministic failure surfaces quickly, per the design's own caveat.
    private const DEFAULT_THRESHOLD = 3;

    // A dead webhook_id shows up as one of these: -400 because HA sends no body
    // (Connect IQ reports that as invalid-http-body), or 404 when the id is gone.
    private const INVALID_WEBHOOK_CODES = [
        Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE,
        404
    ];

    private var _client as HaClient;
    private var _request as Method;
    private var _callback as Method;
    private var _attemptsLeft as Number;
    private var _hasReregistered as Boolean;

    function initialize(client as HaClient, request as Method, callback as Method) {
        _client = client;
        _request = request;
        _callback = callback;
        _attemptsLeft = DEFAULT_THRESHOLD;
        _hasReregistered = false;
    }

    function attempt() as Void {
        _request.invoke(method(:onAttempt));
    }

    function onAttempt(result as Object or Null, error as Number or Null) as Void {
        if (error == null) {
            _callback.invoke(result, null);
            return;
        }

        if (isInvalidWebhookCode(error)) {
            // Bounded to one re-registration cycle per request: a webhook id
            // that is invalid again right after a fresh registration is a
            // Home Assistant-side condition this loop cannot fix by
            // repeating itself, so it surfaces rather than falling through
            // to the generic reissue below.
            if (_hasReregistered) {
                _callback.invoke(null, error);
                return;
            }

            _hasReregistered = true;
            Webhook.clearId();
            _client.register(method(:onRegistered));
            return;
        }

        if (_attemptsLeft <= 0) {
            _callback.invoke(null, error);
            return;
        }

        _attemptsLeft--;
        _request.invoke(method(:onAttempt));
    }

    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
        if (error != null) {
            _callback.invoke(null, error);
            return;
        }

        // The reissued request is fresh and carries its own budget: registering
        // recovered, so the original failure counted for nothing.
        _attemptsLeft = DEFAULT_THRESHOLD;
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
}
