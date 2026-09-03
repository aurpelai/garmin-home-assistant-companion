import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class LevelPicker extends WatchUi.View {
    public var attribute as AdjustableAttribute;
    private var _range as LevelRange;
    private var _value as Number;

    function initialize(attribute as AdjustableAttribute) {
        View.initialize();
        self.attribute = attribute;
        _range = attribute.range as LevelRange;
        var current = attribute.current;
        _value = current == null ? _range.min : current;
    }

    function getValue() as Number {
        return _value;
    }

    function increase() as Void {
        _value = _range.next(_value);
        WatchUi.requestUpdate();
    }

    function decrease() as Void {
        _value = _range.previous(_value);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.drawText(width / 2, height * 0.24, Graphics.FONT_TINY,
            WatchUi.loadResource(attribute.titleId) as String, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height / 2, Graphics.FONT_NUMBER_MEDIUM, formatValue(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        Rendering.useAntiAlias(dc, true);
        dc.drawBitmap(confirmation_loc__hint_confirm.x, confirmation_loc__hint_confirm.y,
            WatchUi.loadResource(Rez.Drawables.ConfirmHint) as BitmapResource);
    }

    private function formatValue() as String {
        return Lang.format(WatchUi.loadResource(attribute.unitId as ResourceId) as String, [_value]);
    }
}
