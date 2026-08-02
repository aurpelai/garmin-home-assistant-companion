import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class ErrorDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // A fresh LoadingView re-runs the fetch in its onShow.
    function onSelect() as Boolean {
        WatchUi.switchToView(new LoadingView(), new LoadingDelegate(), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Boolean {
        // System.exit() does not return, so no explicit return is reachable.
        System.exit();
    }
}
