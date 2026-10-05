import Toybox.Lang;
import Toybox.Timer;

class TimerScheduler {
    private var _timer as Timer.Timer;

    function initialize() {
        _timer = new Timer.Timer();
    }

    function scheduleAction(action as Method() as Void, delayMs as Number) as Void {
        _timer.start(action, delayMs, false);
    }

    function cancel() as Void {
        _timer.stop();
    }
}
