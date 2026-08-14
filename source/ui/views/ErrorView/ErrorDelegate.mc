import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class ErrorDelegate extends WatchUi.BehaviorDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        BehaviorDelegate.initialize();
        _coordinator = coordinator;
    }

    // A fresh LoadingView re-runs the fetch when the coordinator sees it reveal.
    function onSelect() as Boolean {
        WatchUi.switchToView(new LoadingView(_coordinator), new LoadingDelegate(), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Boolean {
        // System.exit() does not return, so no explicit return is reachable.
        System.exit();
    }
}
