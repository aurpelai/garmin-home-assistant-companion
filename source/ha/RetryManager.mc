import Toybox.Lang;

class RetryManager {
    private const REQUEST_RETRIES = 3;
    private const REGISTRATION_RETRIES = 1;

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

        if (reason == RequestError.HTTP_NOT_FOUND) {
            if (_registrationsLeft <= 0) {
                reportFailure(reason, _requestType);
                return;
            }

            _registrationsLeft--;
            _client.discardRegistration();
            _client.register(method(:onRegistered));
            return;
        }

        if (_attemptsLeft <= 0) {
            reportFailure(reason, _requestType);
            return;
        }

        _attemptsLeft--;
        _request.invoke(method(:onAttempt));
    }

    function onRegistered(webhookId as String or Null, reason as Object or Null) as Void {
        if (reason != null) {
            reportFailure(reason, RequestType.REGISTRATION);
            return;
        }

        // The reissued request is fresh and carries its own budget: registering
        // recovered, so the original failure counted for nothing.
        _attemptsLeft = REQUEST_RETRIES;
        _request.invoke(method(:onAttempt));
    }

    private function reportFailure(reason as Object, requestType as Symbol) as Void {
        _callback.invoke(null, new RequestError(reason, requestType));
    }
}
