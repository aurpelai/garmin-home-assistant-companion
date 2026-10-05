import Toybox.Lang;

class ScheduledAction {
    var action as Method() as Void;
    var dueAt as Number;

    function initialize(action as Method() as Void, dueAt as Number) {
        self.action = action;
        self.dueAt = dueAt;
    }
}
