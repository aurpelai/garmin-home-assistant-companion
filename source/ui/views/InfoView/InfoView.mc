import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class InfoView extends WatchUi.View {
    hidden var textArea as WatchUi.TextArea;
    hidden var selectable as Boolean;

    function initialize(message as String, selectable as Boolean) {
        View.initialize();
        self.selectable = selectable;

        var text = selectable
            ? message + "\n\n" + (WatchUi.loadResource(Rez.Strings.RetryHint) as String)
            : message;

        textArea = new WatchUi.TextArea({
            :text => text,
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

        if (selectable) {
            Rendering.useAntiAlias(dc, true);
            dc.drawBitmap(
                system_loc__hint_button_right_top.x,
                system_loc__hint_button_right_top.y,
                WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource);
        }
    }
}
