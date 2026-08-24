import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class InfoView extends WatchUi.View {
    hidden var textArea as WatchUi.TextArea;
    hidden var selectable as Boolean;
    hidden var detail as String or Null;

    function initialize(message as String, selectable as Boolean, detail as String or Null) {
        View.initialize();
        self.selectable = selectable;
        self.detail = detail;

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

        dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
        dc.clear();
        textArea.setLocation(width * 0.2, height * 0.2);
        textArea.setSize(width * 0.6, height * 0.6);
        textArea.draw(dc);

        if (detail != null) {
            Rendering.useAntiAlias(dc, true);
            dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
            dc.drawText(width / 2, height * 0.85, Graphics.FONT_XTINY, detail as String,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (selectable) {
            Rendering.useAntiAlias(dc, true);
            dc.drawBitmap(
                system_loc__hint_button_right_top.x,
                system_loc__hint_button_right_top.y,
                WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource);
        }
    }
}
