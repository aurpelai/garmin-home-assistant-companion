import Toybox.Lang;

class RetryManager {
    private const REQUEST_RETRIES = 3;
    private const REGISTRATION_RETRIES = 1;

    private var _client as HaClient;
    private var _request as Method;
    private var _callback as Method;
    private var _requestType as Symbol;
    private var _requestRetriesLeft as Number;
    private var _registrationRetriesLeft as Number;

    function initialize(client as HaClient, request as Method, callback as Method,
                        requestType as Symbol) {
        _client = client;
        _request = request;
        _callback = callback;
        _requestType = requestType;
        _requestRetriesLeft = REQUEST_RETRIES;
        _registrationRetriesLeft = REGISTRATION_RETRIES;
    }

    function attempt() as Void {
        _request.invoke(method(:onAttempt));
    }

    function onAttempt(result as Object or Null, reason as Object or Null) as Void {
        if (reason == null) {
            _callback.invoke(result, null);
            return;
        }

        if (_requestRetriesLeft <= 0) {
            reportFailure(reason, _requestType);
            return;
        }

        _requestRetriesLeft--;

        if (reason == RequestError.UNUSABLE_WEBHOOK) {
            register();
        } else {
            attempt();
        }
    }

    function onRegistered(webhookId as String or Null, reason as Object or Null) as Void {
        if (reason == null) {
            attempt();
            return;
        }

        if (_registrationRetriesLeft <= 0) {
            reportFailure(reason, RequestType.REGISTRATION);
            return;
        }

        _registrationRetriesLeft--;
        register();
    }

    private function register() as Void {
        _client.register(method(:onRegistered));
    }

    private function reportFailure(reason as Object, requestType as Symbol) as Void {
        _callback.invoke(null, new RequestError(reason, requestType));
    }
}
