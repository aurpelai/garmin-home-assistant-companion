import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class InfoView extends WatchUi.View {
    hidden var textArea as WatchUi.TextArea;

    function initialize(message as String) {
        View.initialize();
        textArea = new WatchUi.TextArea({
            :text => message + "\n\n" + (WatchUi.loadResource(Rez.Strings.RetryHint) as String),
            :color => system_color_dark__text.color,
            :backgroundColor => system_color_dark__text.background,
            :justification => Graphics.TEXT_JUSTIFY_CENTER,
            :font => [Graphics.FONT_TINY, Graphics.FONT_XTINY],
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(system_color_dark__text.color, Graphics.COLOR_BLACK);
        dc.clear();
        textArea.setLocation(width * 0.2, height * 0.2);
        textArea.setSize(width * 0.6, height * 0.6);
        textArea.draw(dc);
    }
}
