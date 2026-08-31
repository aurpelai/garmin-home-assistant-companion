import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class ReadingChip {
    private const HORIZONTAL_PADDING = 10;
    private const VERTICAL_PADDING = 5;
    private const BORDER_RADIUS = 8;
    private const ICON_GAP = 6;

    private const FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedRegular", "RobotoRegular"],
        :size => (WatchUi.loadResource(Rez.JsonData.VectorFontSizes) as Dictionary).get("medium") as Number
    }) as Graphics.VectorFont;

    private var _text as String;
    private var _icon as WatchUi.BitmapResource or Null;
    private var _iconTint as Number;

    function initialize(reading as SensorReading, iconTint as Number or Null) {
        _text = reading.text;
        _icon = resolveIcon(reading.deviceClass);
        _iconTint = iconTint != null ? iconTint : Graphics.COLOR_LT_GRAY;
    }

    function draw(dc as Graphics.Dc, x as Number, y as Number) as Void {
        var icon = _icon;
        var textWidth = dc.getTextWidthInPixels(_text, FONT);
        var textHeight = dc.getFontHeight(FONT);
        var leadingWidth = icon != null ? icon.getWidth() + ICON_GAP : 0;
        var contentWidth = leadingWidth + textWidth;

        Rendering.useAntiAlias(dc, true);

        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawRoundedRectangle(
            x - HORIZONTAL_PADDING - contentWidth / 2,
            y - VERTICAL_PADDING,
            contentWidth + 2 * HORIZONTAL_PADDING,
            textHeight + 2 * VERTICAL_PADDING,
            BORDER_RADIUS
        );

        var contentLeft = x - contentWidth / 2;

        if (icon != null) {
            Rendering.useAntiAlias(dc, true);
            dc.drawBitmap2(contentLeft, y + textHeight / 2 - icon.getHeight() / 2, icon, {
                :tintColor => _iconTint
            });
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(contentLeft + leadingWidth, y, FONT, _text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function resolveIcon(deviceClass as String) as WatchUi.BitmapResource or Null {
        if ("temperature".equals(deviceClass)) {
            return WatchUi.loadResource(Rez.Drawables.Temperature) as WatchUi.BitmapResource;
        }

        if ("humidity".equals(deviceClass)) {
            return WatchUi.loadResource(Rez.Drawables.Humidity) as WatchUi.BitmapResource;
        }

        if ("illuminance".equals(deviceClass)) {
            return WatchUi.loadResource(Rez.Drawables.Brightness) as WatchUi.BitmapResource;
        }

        return null;
    }
}
