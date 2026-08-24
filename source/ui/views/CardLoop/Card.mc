import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Card {
    private const GRID_SIZE = 12;

    private const BOX_HORIZONTAL_PADDING = 10;
    private const BOX_VERTICAL_PADDING = 5;
    private const BOX_BORDER_RADIUS = 6;

    private const FONT_SIZES = WatchUi.loadResource(Rez.JsonData.VectorFontSizes) as Dictionary;

    private const TITLE_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedBold", "RobotoRegular"],
        :size => FONT_SIZES.get("large") as Number
    }) as Graphics.VectorFont;

    private const SUBTITLE_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedBold", "RobotoRegular"],
        :size => FONT_SIZES.get("small") as Number
    }) as Graphics.VectorFont;

    private const LABEL_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedRegular", "RobotoRegular"],
        :size => FONT_SIZES.get("medium") as Number
    }) as Graphics.VectorFont;

    public var id as String;
    public var floorId as String or Null;
    public var name as String;
    public var readings as Array<SensorReading>;

    function initialize(id as String, floorId as String or Null, name as String,
                        readings as Array<SensorReading>) {
        self.id = id;
        self.floorId = floorId;
        self.name = name;
        self.readings = readings;
    }

    function draw(dc as Graphics.Dc) as Void {
    }

    function open(coordinator as Coordinator) as Void {
    }

    hidden function drawFrame(dc as Graphics.Dc, subtitle as String or Null) as Void {
        var centerX = dc.getWidth() / 2;

        Rendering.useAntiAlias(dc, true);

        if (subtitle != null) {
            drawSubtitle(dc, centerX, getRowY(dc, 2), subtitle as String);
        }

        drawTitle(dc, centerX, getRowY(dc, 3), name);
        drawReadings(dc);
        drawSelectHint(dc);
    }

    hidden function getRowY(dc as Graphics.Dc, row as Number) as Number {
        return dc.getHeight() * row / GRID_SIZE;
    }

    hidden function getColumnX(dc as Graphics.Dc, column as Number) as Number {
        return dc.getWidth() * column / GRID_SIZE;
    }

    private function drawTitle(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        Rendering.useAntiAlias(dc, true);
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(x, y, TITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSubtitle(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        Rendering.useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawText(x, y, SUBTITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLightIcon(dc as Graphics.Dc, x as Number, y as Number,
                                  icon as WatchUi.BitmapResource, tint as Number) as Void {
        dc.drawBitmap2(x - icon.getWidth() / 2, y - icon.getHeight() / 2, icon, {
            :tintColor => tint
        });
    }

    private function drawReadings(dc as Graphics.Dc) as Void {
        for (var index = 0; index < readings.size(); index++) {
            var reading = readings[index];

            if ("temperature".equals(reading.deviceClass)) {
                drawReadingBox(dc, getColumnX(dc, 4),
                    getRowY(dc, 8), reading.text);
            } else if ("humidity".equals(reading.deviceClass)) {
                drawReadingBox(dc, getColumnX(dc, 8),
                    getRowY(dc, 8), reading.text);
            } else if ("illuminance".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() / 2,
                    getRowY(dc, 10), reading.text);
            }
        }
    }

    private function drawReadingBox(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        var textWidth = dc.getTextWidthInPixels(text, LABEL_FONT);
        var textHeight = dc.getFontHeight(LABEL_FONT);

        Rendering.useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawRoundedRectangle(
            x - BOX_HORIZONTAL_PADDING - textWidth / 2,
            y - BOX_VERTICAL_PADDING,
            textWidth + 2 * BOX_HORIZONTAL_PADDING,
            textHeight + 2 * BOX_VERTICAL_PADDING,
            BOX_BORDER_RADIUS);

        Rendering.useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(x, y, LABEL_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSelectHint(dc as Graphics.Dc) as Void {
        Rendering.useAntiAlias(dc, true);
        dc.drawBitmap(
            system_loc__hint_button_right_top.x,
            system_loc__hint_button_right_top.y,
            WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource);
    }
}
