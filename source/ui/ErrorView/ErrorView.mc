import Toybox.Graphics;
import Toybox.Lang;
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
