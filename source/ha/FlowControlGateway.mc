import Toybox.Communications;
import Toybox.Lang;

// Connect IQ can leave a request unanswered indefinitely and refuses a post
// outright while its queue is full (both observed in the simulator on
// 2026-10-05). Every attempt therefore times out on its own, and a refused one,
// never having been sent, waits for a slot instead of spending a retry.
class FlowControlGateway {
    private const TIMEOUT_MS = 10 * 1000;
    private const QUEUE_FULL_RETRY_MS = 500;

    private var _gateway as RequestGateway;
    private var _scheduler as Scheduler;
    private var _inFlightCount as Number;
    private var _held as Array<RequestAttempt>;

    function initialize(gateway as RequestGateway, scheduler as Scheduler) {
        _gateway = gateway;
        _scheduler = scheduler;
        _inFlightCount = 0;
        _held = [];
    }

    function onQueueFull(attempt as RequestAttempt) as Void {
        _inFlightCount--;
        _held.add(attempt);

        if (_inFlightCount == 0) {
            _scheduler.schedule(method(:resendHeld), QUEUE_FULL_RETRY_MS);
        }
    }

    function onSettled(attempt as RequestAttempt) as Void {
        if (!_held.remove(attempt)) {
            _inFlightCount--;
        }

        resendHeld();
    }

    function post(path as String, body as Dictionary, onResponse as Method) as Void {
        var attempt = new RequestAttempt(self, path, body, onResponse);
        _scheduler.schedule(attempt.method(:onTimeout), TIMEOUT_MS);
        send(attempt);
    }

    function cancelAll() as Void {
        _held = [];
        _gateway.cancelAll();
    }

    function resendHeld() as Void {
        var held = _held;
        _held = [];

        for (var i = 0; i < held.size(); i++) {
            send(held[i]);
        }
    }

    private function send(attempt as RequestAttempt) as Void {
        _inFlightCount++;
        _gateway.post(attempt.path, attempt.body, attempt.method(:onResponse));
    }
}
