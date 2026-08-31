import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A message addressed to the user, held until the user dismisses it: state
// changing underneath must neither replace it nor refresh it.
class InfoView extends WatchUi.View {
    private var _coordinator as Coordinator;
    private var _textArea as WatchUi.TextArea;
    private var _selectable as Boolean;
    private var _detail as String or Null;

    function initialize(coordinator as Coordinator, message as String, selectable as Boolean,
                        detail as String or Null) {
        View.initialize();
        _coordinator = coordinator;
        _selectable = selectable;
        _detail = detail;

        var text = selectable
            ? message + "\n\n" + (WatchUi.loadResource(Rez.Strings.RetryHint) as String)
            : message;

        _textArea = new WatchUi.TextArea({
            :text => text,
            :color => system_color_dark__text.color,
            :backgroundColor => system_color_dark__text.background,
            :justification => Graphics.TEXT_JUSTIFY_CENTER,
            :font => [Graphics.FONT_TINY, Graphics.FONT_XTINY],
        });
    }

    function onShow() as Void {
        _coordinator.onMessageShown(self);
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
        dc.clear();
        _textArea.setLocation(width * 0.2, height * 0.2);
        _textArea.setSize(width * 0.6, height * 0.6);
        _textArea.draw(dc);

        if (_detail != null) {
            Rendering.useAntiAlias(dc, true);
            dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
            dc.drawText(width / 2, height * 0.85, Graphics.FONT_XTINY, _detail as String,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_selectable) {
            Rendering.useAntiAlias(dc, true);
            dc.drawBitmap(
                system_loc__hint_button_right_top.x,
                system_loc__hint_button_right_top.y,
                WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource);
        }
    }
}
