import Toybox.Lang;

class RetryManager {
    private const MAX_REQUEST_ATTEMPTS = 4;
    private const MAX_REGISTRATION_ATTEMPTS = 2;
    private const RETRY_DELAY_MS = 100;

    private var _request as Method;
    private var _callback as Method;
    private var _scheduler as Scheduler;
    private var _attemptsLeft as Number;

    function initialize(request as Method, callback as Method, scheduler as Scheduler,
                        requestType as Symbol) {
        _request = request;
        _callback = callback;
        _scheduler = scheduler;
        _attemptsLeft = requestType == RequestType.REGISTRATION
            ? MAX_REGISTRATION_ATTEMPTS
            : MAX_REQUEST_ATTEMPTS;
    }

    // The retry is scheduled rather than called inline, so the stack unwinds
    // between attempts. A request that fails synchronously — a missing webhook id
    // needs no round trip to reject — would otherwise recurse until it overflows.
    function onAttempt(result as Object or Null, error as RequestError or Null) as Void {
        if (error == null) {
            _callback.invoke(result, null);
            return;
        }

        if (_attemptsLeft <= 0) {
            _callback.invoke(null, error);
            return;
        }

        _scheduler.schedule(method(:attempt), RETRY_DELAY_MS);
    }

    function attempt() as Void {
        _attemptsLeft--;
        _request.invoke(method(:onAttempt));
    }
}
