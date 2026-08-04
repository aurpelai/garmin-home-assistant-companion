import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class ErrorView extends WatchUi.View {
    hidden var textArea as WatchUi.TextArea;

    function initialize(message as String) {
        View.initialize();
        textArea = new WatchUi.TextArea({
            :text => message + "\n\n" + (WatchUi.loadResource(Rez.Strings.RetryHint) as String),
            :color => Graphics.COLOR_WHITE,
            :justification => Graphics.TEXT_JUSTIFY_CENTER,
            :font => [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY],
            :locX => 20,
            :locY => 20,
            :width => 240,
            :height => 240
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        textArea.draw(dc);
    }
}
