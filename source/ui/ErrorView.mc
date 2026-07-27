import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Initial-load dead-end screen: a centered, wrapped message ending in a retry
// hint, used both for load errors and for a load that found no lights.
// Select/enter retries the load (this is the one state with no cache to fall
// back on); Back exits the app.
class ErrorView extends WatchUi.View {
    private var _message as String;

    function initialize(message as String) {
        View.initialize();
        _message = message + "\n\n" + (WatchUi.loadResource(Rez.Strings.RetryHint) as String);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        CenteredMessage.draw(dc, _message);
    }
}

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
