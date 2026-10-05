import Toybox.Lang;
import Toybox.Test;

// Holds the scheduled retry so a test can run it on demand, standing in for the
// real Scheduler's timer, which never fires inside the test harness.
(:test)
class FakeScheduler {
    private var _pending as Method or Null = null;

    function schedule(action as Method() as Void, delayMs as Number) as Void {
        _pending = action;
    }

    function cancel() as Void {
        _pending = null;
    }

    function runScheduled() as Void {
        var action = _pending;
        _pending = null;
        if (action != null) {
            action.invoke();
        }
    }
}

(:test)
class FakeRequest {
    public var attempts as Number = 0;
    private var _callback as Method or Null = null;

    function attempt(callback as Method) as Void {
        attempts++;
        _callback = callback;
    }

    function settle(result as Object?, error as RequestError?) as Void {
        (_callback as Method).invoke(result, error);
    }
}

(:test)
function retryManagerReissuesAFailedRequestUntilItSucceeds(logger as Test.Logger) as Boolean {
    var request = new FakeRequest();
    var scheduler = new FakeScheduler();
    var capture = new ResultCapture();

    new RetryManager(request.method(:attempt), capture.method(:onResult), scheduler, RequestType.REQUEST).attempt();
    request.settle(null, new RequestError(-1, null));
    scheduler.runScheduled();
    request.settle(true, null);

    Test.assertEqual(request.attempts, 2);
    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerSurfacesTheFailureOnceItsThresholdIsSpent(logger as Test.Logger) as Boolean {
    var request = new FakeRequest();
    var scheduler = new FakeScheduler();
    var capture = new ResultCapture();

    new RetryManager(request.method(:attempt), capture.method(:onResult), scheduler, RequestType.REQUEST).attempt();

    for (var i = 0; i < 4; i++) {
        request.settle(null, new RequestError(-1, null));
        scheduler.runScheduled();
    }

    Test.assertEqual(request.attempts, 4);
    Test.assertEqual((capture.error as RequestError).reason as Number, -1);
    return true;
}

(:test)
function retryManagerGivesARegistrationFewerAttempts(logger as Test.Logger) as Boolean {
    var request = new FakeRequest();
    var scheduler = new FakeScheduler();
    var capture = new ResultCapture();

    new RetryManager(request.method(:attempt), capture.method(:onResult), scheduler, RequestType.REGISTRATION).attempt();

    for (var i = 0; i < 2; i++) {
        request.settle(null, new RequestError(HttpStatus.BAD_REQUEST, RequestType.REGISTRATION));
        scheduler.runScheduled();
    }

    Test.assertEqual(request.attempts, 2);
    Test.assertEqual((capture.error as RequestError).reason as Number, HttpStatus.BAD_REQUEST);
    return true;
}
