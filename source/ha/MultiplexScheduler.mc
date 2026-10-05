import Toybox.Lang;
import Toybox.System;

class MultiplexScheduler {
    // Connect IQ rejects a timer below its minimum, 50 ms by default (api.mir Timer docs, SDK 9.2.0).
    private const MIN_DELAY_MS = 50;

    private var _timer as Scheduler;
    private var _entries as Array<[Method, Number]>;
    private var _armedDueAt as Number or Null;

    function initialize(timer as Scheduler) {
        _timer = timer;
        _entries = [];
        _armedDueAt = null;
    }

    // The timer firing stands for its armed due time having arrived.
    function onTimer() as Void {
        var now = System.getTimer();
        var armedDueAt = _armedDueAt;

        if (armedDueAt != null && armedDueAt > now) {
            now = armedDueAt;
        }

        var due = [] as Array<Method>;
        var later = [] as Array<[Method, Number]>;

        for (var i = 0; i < _entries.size(); i++) {
            var entry = _entries[i];

            if (entry[1] <= now) {
                due.add(entry[0]);
            } else {
                later.add(entry);
            }
        }

        _entries = later;
        _armedDueAt = null;
        arm();

        for (var i = 0; i < due.size(); i++) {
            due[i].invoke();
        }
    }

    function schedule(action as Method() as Void, delayMs as Number) as Void {
        _entries.add([action, System.getTimer() + delayMs]);
        arm();
    }

    function cancel() as Void {
        _entries = [];
        _armedDueAt = null;
        _timer.cancel();
    }

    private function arm() as Void {
        if (_entries.size() == 0) {
            return;
        }

        var earliest = _entries[0][1];

        for (var i = 1; i < _entries.size(); i++) {
            if (_entries[i][1] < earliest) {
                earliest = _entries[i][1];
            }
        }

        if (_armedDueAt != null && _armedDueAt <= earliest) {
            return;
        }

        _armedDueAt = earliest;
        _timer.cancel();
        var delayMs = earliest - System.getTimer();
        _timer.schedule(method(:onTimer), delayMs < MIN_DELAY_MS ? MIN_DELAY_MS : delayMs);
    }
}
