import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A message addressed to the user, held until the user dismisses it: state
// changing underneath must neither replace it nor refresh it.
class InfoView extends WatchUi.View {
    private const CODE_FONT = Graphics.FONT_XTINY;

    private var _coordinator as Coordinator;
    private var _message as String;
    private var _codes as Array<String>;
    private var _retryHint as String or Null;

    function initialize(coordinator as Coordinator, message as String, isSelectable as Boolean,
                        codes as Array<String>) {
        View.initialize();
        _coordinator = coordinator;
        _message = message;
        _codes = codes;
        _retryHint = isSelectable ? WatchUi.loadResource(Rez.Strings.RetryHint) as String : null;
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
        var codesHeight = _codes.size() * dc.getFontHeight(CODE_FONT);

        dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
        dc.clear();
        Rendering.useAntiAlias(dc, true);

        var codesTop = drawMessage(dc, width / 2, height * 0.2, width * 0.6, height * 0.6 - codesHeight);
        drawCodes(dc, width / 2, codesTop);

        if (_retryHint != null) {
            drawRetryHint(dc, width / 2, height * 0.85);
        }
    }

    private function drawMessage(dc as Graphics.Dc, x as Number, y as Numeric, width as Numeric,
                                 maxHeight as Numeric) as Numeric {
        var font = Graphics.FONT_TINY;
        var text = Graphics.fitTextToArea(_message, font, width, maxHeight, false);

        if (text == null) {
            font = Graphics.FONT_XTINY;
            text = Graphics.fitTextToArea(_message, font, width, maxHeight, true);
        }

        var lines = text != null ? text : _message;
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(x, y, font, lines, Graphics.TEXT_JUSTIFY_CENTER);

        return y + dc.getTextDimensions(lines, font)[1] + dc.getFontHeight(font);
    }

    private function drawCodes(dc as Graphics.Dc, x as Number, y as Numeric) as Void {
        var rowHeight = dc.getFontHeight(CODE_FONT);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);

        for (var i = 0; i < _codes.size(); i++) {
            dc.drawText(x, y + i * rowHeight, CODE_FONT, _codes[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawRetryHint(dc as Graphics.Dc, x as Number, y as Numeric) as Void {
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(x, y, Graphics.FONT_XTINY, _retryHint as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawBitmap(
            system_loc__hint_button_right_top.x,
            system_loc__hint_button_right_top.y,
            WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource);
    }
}
