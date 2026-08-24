import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// One screen-full of the card loop, drawing itself — which is why a card is not
// a Model. Subclasses supply the middle band that differs per type; everything
// else here is shared by all of them.
//
// Fonts, colors, and the select-key hint come from the device's SDK personality
// (System 6 / API 5.0.0), so they track the watch theme instead of being
// hand-picked.
class Card {
    private const GRID_SIZE = 12;
    private const LIGHT_INDICATOR_GAP = 4;

    private const BOX_HORIZONTAL_PADDING = 10;
    private const BOX_VERTICAL_PADDING = 5;
    private const BOX_BORDER_RADIUS = 6;

    private const LIGHTBULB_ON = WatchUi.loadResource(Rez.Drawables.LightbulbOnOutline) as WatchUi.BitmapResource;
    private const LIGHTBULB_OFF = WatchUi.loadResource(Rez.Drawables.LightbulbOutline) as WatchUi.BitmapResource;
    private const LIGHTBULB_UNAVAILABLE = WatchUi.loadResource(Rez.Drawables.LightbulbOffOutline) as WatchUi.BitmapResource;

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

    // Read from outside by the loop, which restores focus by id and falls back
    // to floorId; anything only a card's own drawing needs stays private.
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
            drawSubtitle(dc, centerX, dc.getHeight() * 2 / GRID_SIZE, subtitle as String);
        }

        drawTitle(dc, centerX, dc.getHeight() * 3 / GRID_SIZE, name);
        drawReadings(dc);
        drawSelectHint(dc);
    }

    hidden function drawLightStatus(dc as Graphics.Dc, text as String) as Void {
        Rendering.useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(dc.getWidth() / 2, middleBandY(dc), SUBTITLE_FONT, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawLightIndicators(dc as Graphics.Dc, lights as LightTally) as Void {
        var totalCount = lights.available + lights.unavailable;
        var step = LIGHTBULB_ON.getWidth() + LIGHT_INDICATOR_GAP;
        var firstX = dc.getWidth() / 2 - (totalCount - 1) * step / 2;
        var centerY = middleBandY(dc);

        for (var index = 0; index < totalCount; index++) {
            var x = firstX + index * step;

            if (index < lights.on) {
                drawLightIcon(dc, x, centerY, LIGHTBULB_ON, Graphics.COLOR_YELLOW);
            } else if (index < lights.available) {
                drawLightIcon(dc, x, centerY, LIGHTBULB_OFF, Graphics.COLOR_LT_GRAY);
            } else {
                drawLightIcon(dc, x, centerY, LIGHTBULB_UNAVAILABLE, Graphics.COLOR_DK_GRAY);
            }
        }
    }

    private function middleBandY(dc as Graphics.Dc) as Number {
        return dc.getHeight() * 6 / GRID_SIZE;
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

    private function drawLightIcon(dc as Graphics.Dc, x as Number, y as Number,
                                   icon as WatchUi.BitmapResource, tint as Number) as Void {
        dc.drawBitmap2(x - icon.getWidth() / 2, y - icon.getHeight() / 2, icon, {
            :tintColor => tint
        });
    }

    private function drawReadings(dc as Graphics.Dc) as Void {
        for (var index = 0; index < readings.size(); index++) {
            var reading = readings[index];

            if ("temperature".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() * 4 / GRID_SIZE,
                    dc.getHeight() * 8 / GRID_SIZE, reading.text);
            } else if ("humidity".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() * 8 / GRID_SIZE,
                    dc.getHeight() * 8 / GRID_SIZE, reading.text);
            } else if ("illuminance".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() / 2,
                    dc.getHeight() * 10 / GRID_SIZE, reading.text);
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
