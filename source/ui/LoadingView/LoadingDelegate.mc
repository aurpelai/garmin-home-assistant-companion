import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Input delegate for the loading screen. The load itself is orchestrated by
// LoadingView.onShow(); this delegate only handles Back (exit) while loading.
class LoadingDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        System.exit();
    }
}
