import Toybox.Lang;

// Runs an action later, off the current call stack.
typedef Scheduler as interface {
    function scheduleAction(action as Method() as Void, delayMs as Number) as Void;
    function cancel() as Void;
};
