import Toybox.Lang;
import Toybox.System;

class MultiplexScheduler {
    // Connect IQ's minimum timer delay is 50 ms by default (verified from the Connect
    // IQ SDK's api.mir on 2026-10-05).
    private const MIN_DELAY_MS = 50;

    private var _timer as Scheduler;
    private var _scheduledActions as Array<ScheduledAction>;
    private var _timerFiresAt as Number or Null;

    function initialize(timer as Scheduler) {
        _timer = timer;
        _scheduledActions = [];
        _timerFiresAt = null;
    }

    function onTimer() as Void {
        var dueBy = System.getTimer();
        var timerFiresAt = _timerFiresAt;

        if (timerFiresAt != null && timerFiresAt > dueBy) {
            dueBy = timerFiresAt;
        }

        var dueActions = [] as Array<ScheduledAction>;
        var remainingActions = [] as Array<ScheduledAction>;

        for (var i = 0; i < _scheduledActions.size(); i++) {
            var scheduledAction = _scheduledActions[i];

            if (scheduledAction.dueAt <= dueBy) {
                dueActions.add(scheduledAction);
            } else {
                remainingActions.add(scheduledAction);
            }
        }

        _scheduledActions = remainingActions;
        _timerFiresAt = null;
        scheduleTimer();

        for (var i = 0; i < dueActions.size(); i++) {
            dueActions[i].action.invoke();
        }
    }

    function cancel() as Void {
        _scheduledActions = [];
        _timerFiresAt = null;
        _timer.cancel();
    }

    function scheduleAction(action as Method() as Void, delayMs as Number) as Void {
        _scheduledActions.add(new ScheduledAction(action, System.getTimer() + delayMs));
        scheduleTimer();
    }

    private function scheduleTimer() as Void {
        if (_scheduledActions.size() == 0) {
            return;
        }

        var nextDueAt = _scheduledActions[0].dueAt;

        for (var i = 1; i < _scheduledActions.size(); i++) {
            if (_scheduledActions[i].dueAt < nextDueAt) {
                nextDueAt = _scheduledActions[i].dueAt;
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
