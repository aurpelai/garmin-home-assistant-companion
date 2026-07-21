import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Terminal error screen: a centered, wrapped message. Back exits the app.
class ErrorView extends WatchUi.View {
    private var _message as String;

    function initialize(message as String) {
        View.initialize();
        _message = message;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        CenteredMessage.draw(dc, _message);
    }
}

class ErrorDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        // System.exit() does not return, so no explicit return is reachable.
        System.exit();
    }
}
