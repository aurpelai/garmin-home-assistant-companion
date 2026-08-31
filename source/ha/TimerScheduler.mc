import Toybox.Lang;
import Toybox.Timer;

// The only object that touches Timer: it holds when the client resumes work.
class TimerScheduler {
    private var _timer as Timer.Timer;

    function initialize() {
        _timer = new Timer.Timer();
    }

    function schedule(action as Method() as Void, delayMs as Number) as Void {
        _timer.start(action, delayMs, false);
    }

    function cancel() as Void {
        _timer.stop();
    }
}
