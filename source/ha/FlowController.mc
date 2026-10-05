import Toybox.Communications;
import Toybox.Lang;

// Connect IQ can leave a request unanswered indefinitely and refuses a post
// outright while its queue is full (both verified in the simulator on
// 2026-10-05). Every attempt therefore times out on its own, and a refused one,
// never having been sent, waits for a slot instead of spending a retry.
class FlowController {
    private const TIMEOUT_MS = 10 * 1000;
    private const QUEUE_FULL_RETRY_MS = 500;

    private var _gateway as RequestGateway;
    private var _scheduler as Scheduler;
    private var _inFlight as Array<RequestAttempt>;
    private var _deferred as Array<RequestAttempt>;

    function initialize(gateway as RequestGateway, scheduler as Scheduler) {
        _gateway = gateway;
        _scheduler = scheduler;
        _inFlight = [];
        _deferred = [];
    }

    function onQueueFull(attempt as RequestAttempt) as Void {
        _inFlight.remove(attempt);
        _deferred.add(attempt);

        if (_inFlight.size() == 0) {
            _scheduler.scheduleAction(method(:resendDeferred), QUEUE_FULL_RETRY_MS);
        }
    }

    function onSettled(attempt as RequestAttempt) as Void {
        if (!_deferred.remove(attempt)) {
            _inFlight.remove(attempt);
        }

        resendDeferred();
    }

    function post(path as String, body as Dictionary, onResponse as Method) as Void {
        var attempt = new RequestAttempt(self, path, body, onResponse);
        _scheduler.scheduleAction(attempt.method(:onTimeout), TIMEOUT_MS);
        send(attempt);
    }

    function cancelAll() as Void {
        var attempts = _inFlight.addAll(_deferred);
        _inFlight = [];
        _deferred = [];

        for (var i = 0; i < attempts.size(); i++) {
            attempts[i].cancel();
        }

        _gateway.cancelAll();
    }

    function resendDeferred() as Void {
        var deferred = _deferred;
        _deferred = [];

        for (var i = 0; i < deferred.size(); i++) {
            send(deferred[i]);
        }
    }

    private function send(attempt as RequestAttempt) as Void {
        _inFlight.add(attempt);
        _gateway.post(attempt.path, attempt.body, attempt.method(:onResponse));
    }
}
