import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class InfoDelegate extends WatchUi.BehaviorDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        BehaviorDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect() as Boolean {
        WatchUi.switchToView(new LoadingView(_coordinator), new LoadingDelegate(), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Boolean {
        System.exit();
    }
}
