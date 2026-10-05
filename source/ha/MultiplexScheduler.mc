import Toybox.Lang;
import Toybox.System;

class MultiplexScheduler {
    // Connect IQ's minimum timer delay is 50 ms by default (verified from the Connect
    // IQ SDK's api.mir on 2026-10-05).
    private const MIN_DELAY_MS = 50;

    private var _timer as Scheduler;
    private var _entries as Array<[Method, Number]>;
    private var _timerFiresAt as Number or Null;

    function initialize(timer as Scheduler) {
        _timer = timer;
        _entries = [];
        _timerFiresAt = null;
    }

    function onTimer() as Void {
        var dueBy = System.getTimer();
        var timerFiresAt = _timerFiresAt;

        if (timerFiresAt != null && timerFiresAt > dueBy) {
            dueBy = timerFiresAt;
        }

        var dueActions = [] as Array<Method>;
        var remainingEntries = [] as Array<[Method, Number]>;

        for (var i = 0; i < _entries.size(); i++) {
            var entry = _entries[i];

            if (entry[1] <= dueBy) {
                dueActions.add(entry[0]);
            } else {
                remainingEntries.add(entry);
            }
        }

        _entries = remainingEntries;
        _timerFiresAt = null;
        arm();

        for (var i = 0; i < dueActions.size(); i++) {
            dueActions[i].invoke();
        }
    }

    function schedule(action as Method() as Void, delayMs as Number) as Void {
        _entries.add([action, System.getTimer() + delayMs]);
        arm();
    }

    function cancel() as Void {
        _entries = [];
        _timerFiresAt = null;
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

        if (_timerFiresAt != null && _timerFiresAt <= earliest) {
            return;
        }

        _timerFiresAt = earliest;
        _timer.cancel();
        var delayMs = earliest - System.getTimer();
        _timer.schedule(method(:onTimer), delayMs < MIN_DELAY_MS ? MIN_DELAY_MS : delayMs);
    }
}
