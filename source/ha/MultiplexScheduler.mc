import Toybox.Lang;
import Toybox.System;

class MultiplexScheduler {
    // Connect IQ's minimum timer delay is 50 ms by default (verified from the Connect
    // IQ SDK's api.mir on 2026-10-05).
    private const MIN_DELAY_MS = 50;

    private var _timer as Scheduler;
    private var _entries as Array<ScheduledAction>;
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
        var remainingEntries = [] as Array<ScheduledAction>;

        for (var i = 0; i < _entries.size(); i++) {
            var entry = _entries[i];

            if (entry.dueAt <= dueBy) {
                dueActions.add(entry.action);
            } else {
                remainingEntries.add(entry);
            }
        }

        _entries = remainingEntries;
        _timerFiresAt = null;
        scheduleTimer();

        for (var i = 0; i < dueActions.size(); i++) {
            dueActions[i].invoke();
        }
    }

    function cancel() as Void {
        _entries = [];
        _timerFiresAt = null;
        _timer.cancel();
    }

    function scheduleAction(action as Method() as Void, delayMs as Number) as Void {
        _entries.add(new ScheduledAction(action, System.getTimer() + delayMs));
        scheduleTimer();
    }

    private function scheduleTimer() as Void {
        if (_entries.size() == 0) {
            return;
        }

        var nextDueAt = _entries[0].dueAt;

        for (var i = 1; i < _entries.size(); i++) {
            if (_entries[i].dueAt < nextDueAt) {
                nextDueAt = _entries[i].dueAt;
            }
        }

        if (_timerFiresAt != null && _timerFiresAt <= nextDueAt) {
            return;
        }

        var delayMs = nextDueAt - System.getTimer();

        _timerFiresAt = nextDueAt;
        _timer.cancel();
        _timer.scheduleAction(method(:onTimer), delayMs < MIN_DELAY_MS ? MIN_DELAY_MS : delayMs);
    }
}
