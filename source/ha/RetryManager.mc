import Toybox.Lang;

class RetryManager {
    private const MAX_REQUEST_ATTEMPTS = 4;
    private const MAX_REGISTRATION_ATTEMPTS = 2;

    private var _client as HaClient;
    private var _request as Method;
    private var _callback as Method;
    private var _requestType as Symbol;
    private var _attemptsLeft as Number;

    function initialize(client as HaClient, request as Method, callback as Method,
                        requestType as Symbol) {
        _client = client;
        _request = request;
        _callback = callback;
        _requestType = requestType;
        _attemptsLeft = requestType == RequestType.REGISTRATION
            ? MAX_REGISTRATION_ATTEMPTS
            : MAX_REQUEST_ATTEMPTS;
    }

    function attempt() as Void {
        _attemptsLeft--;
        _request.invoke(method(:onAttempt));
    }

    function onAttempt(result as Object or Null, reason as Object or Null) as Void {
        if (reason == null) {
            _callback.invoke(result, null);
            return;
        }

        if (_attemptsLeft <= 0) {
            _callback.invoke(null, new RequestError(reason, _requestType));
            return;
        }

        if (reason == RequestError.UNUSABLE_WEBHOOK) {
            _client.register(method(:onRegistered));
            return;
        }

        attempt();
    }

    function onRegistered(webhookId as String or Null, error as RequestError or Null) as Void {
        if (error != null) {
            _callback.invoke(null, error);
            return;
        }

        attempt();
    }
}
