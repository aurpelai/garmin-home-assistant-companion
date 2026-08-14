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
    private const COLUMN_COUNT = 12;
    private const LIGHT_INDICATOR_RADIUS = 7;
    private const LIGHT_INDICATOR_SAFE_AREA = 4;
    private const LIGHT_INDICATOR_SIZE = 2 * (LIGHT_INDICATOR_RADIUS + LIGHT_INDICATOR_SAFE_AREA);

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

    // Public because the loop reads them from outside: it finds the card to
    // restore focus to by id, and by floorId when that id is gone. Anything only
    // a card's own drawing needs stays private to the type that draws it.
    public var id as String;
    public var floorId as String or Null;
    public var name as String;
    public var readings as Array<CardReading>;

    function initialize(id as String, floorId as String or Null, name as String,
                        readings as Array<CardReading>) {
        self.id = id;
        self.floorId = floorId;
        self.name = name;
        self.readings = readings;
    }

    // Every card type overrides this with the band that differs. Declared here
    // because the loop holds cards as this type and calls it through that: the
    // language has no abstract method, so the base states the contract with an
    // empty body rather than leaving callers to cast per type.
    function draw(dc as Graphics.Dc) as Void {
    }

    // The title, its subtitle and the sensor boxes, which every card type shares.
    // The subtitle is skipped when null: an unfloored area has no floor to name.
    hidden function drawFrame(dc as Graphics.Dc, subtitle as String or Null) as Void {
        var centerX = dc.getWidth() / 2;

        useAntiAlias(dc, true);

        if (subtitle != null) {
            drawSubtitle(dc, centerX, dc.getHeight() * 2 / COLUMN_COUNT, subtitle as String);
        }

        drawTitle(dc, centerX, dc.getHeight() * 3 / COLUMN_COUNT, name);
        drawReadings(dc);
        drawSelectHint(dc);
    }

    hidden function drawLightStatus(dc as Graphics.Dc, text as String) as Void {
        useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(dc.getWidth() / 2, middleBandY(dc), SUBTITLE_FONT, text,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Tally in, dots out: one per physical light, filled yellow while on, filled
    // grey while off, outlined while unavailable.
    hidden function drawLightIndicators(dc as Graphics.Dc, lights as LightTally) as Void {
        var totalCount = lights.available + lights.unavailable;
        var firstX = dc.getWidth() / 2 - (totalCount - 1) * LIGHT_INDICATOR_SIZE / 2;
        var centerY = middleBandY(dc) + LIGHT_INDICATOR_RADIUS;

        for (var index = 0; index < totalCount; index++) {
            var x = firstX + index * LIGHT_INDICATOR_SIZE;

            if (index < lights.on) {
                drawFilledLightIndicator(dc, x, centerY, Graphics.COLOR_YELLOW);
            } else if (index < lights.available) {
                drawFilledLightIndicator(dc, x, centerY, Graphics.COLOR_DK_GRAY);
            } else {
                drawOutlinedLightIndicator(dc, x, centerY);
            }
        }
    }

    hidden function useAntiAlias(dc as Graphics.Dc, enabled as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(enabled);
        }
    }

    // Where a card type's own band sits, the same slot in every layout so the
    // loop does not shift vertically as it pages between types.
    private function middleBandY(dc as Graphics.Dc) as Number {
        return dc.getHeight() / 2 - LIGHT_INDICATOR_RADIUS;
    }

    private function drawTitle(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        useAntiAlias(dc, true);
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(x, y, TITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSubtitle(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawText(x, y, SUBTITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawFilledLightIndicator(dc as Graphics.Dc, x as Number, y as Number,
                                              color as Number) as Void {
        useAntiAlias(dc, true);
        dc.setColor(color, system_color_dark__background.background);
        dc.fillCircle(x, y, LIGHT_INDICATOR_RADIUS);
    }

    private function drawOutlinedLightIndicator(dc as Graphics.Dc, x as Number, y as Number) as Void {
        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.drawCircle(x, y, LIGHT_INDICATOR_RADIUS);
    }

    // Each device class has its own fixed slot, so a card with only humidity
    // still shows it on the right rather than sliding it left.
    private function drawReadings(dc as Graphics.Dc) as Void {
        for (var index = 0; index < readings.size(); index++) {
            var reading = readings[index];

            if ("temperature".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() * 4 / COLUMN_COUNT,
                    dc.getHeight() * 8 / COLUMN_COUNT, reading.text);
            } else if ("humidity".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() * 8 / COLUMN_COUNT,
                    dc.getHeight() * 8 / COLUMN_COUNT, reading.text);
            } else if ("illuminance".equals(reading.deviceClass)) {
                drawReadingBox(dc, dc.getWidth() / 2,
                    dc.getHeight() * 10 / COLUMN_COUNT, reading.text);
            }
        }
    }

    private function drawReadingBox(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        var textWidth = dc.getTextWidthInPixels(text, LABEL_FONT);
        var textHeight = dc.getFontHeight(LABEL_FONT);

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawRoundedRectangle(
            x - BOX_HORIZONTAL_PADDING - textWidth / 2,
            y - BOX_VERTICAL_PADDING,
            textWidth + 2 * BOX_HORIZONTAL_PADDING,
            textHeight + 2 * BOX_VERTICAL_PADDING,
            BOX_BORDER_RADIUS);

        useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(x, y, LABEL_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSelectHint(dc as Graphics.Dc) as Void {
        useAntiAlias(dc, true);
        dc.drawBitmap(
            system_loc__hint_button_right_top.x,
            system_loc__hint_button_right_top.y,
            WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource);
    }
}
