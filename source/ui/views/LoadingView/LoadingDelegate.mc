import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class LoadingDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        System.exit();
    }
}
