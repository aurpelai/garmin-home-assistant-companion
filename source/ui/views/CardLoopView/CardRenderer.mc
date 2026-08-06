import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Draws one card of the top-level loop. Fonts, colors, and the select-key hint
// come from the device's SDK personality (System 6 / API 5.0.0), so they track
// the watch theme instead of being hand-picked.
class CardRenderer {
    private const FONT_SIZES = WatchUi.loadResource(Rez.JsonData.VectorFontSizes) as Dictionary;

    private const TITLE_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedBold", "RobotoRegular"],
        :size => FONT_SIZES.get("large") as Number
    }) as Graphics.VectorFont;

    private const SUBTITLE_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedRegular", "RobotoRegular"],
        :size => FONT_SIZES.get("small") as Number
    }) as Graphics.VectorFont;

    private const LABEL_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedRegular", "RobotoRegular"],
        :size => FONT_SIZES.get("medium") as Number
    }) as Graphics.VectorFont;

    private const SECTION_GAP = 16;
    private const SUMMARY_LINE_GAP = 8;

    private const LIGHT_INDICATOR_RADIUS = 6;
    private const LIGHT_INDICATOR_SPACING = LIGHT_INDICATOR_RADIUS * 3;

    function drawCard(dc as Graphics.Dc, card as Dictionary) as Void {
        useAntiAlias(dc, true);

        if (card.get(:type) == :floor) {
            drawFloorCard(dc, card);
        } else {
            drawAreaCard(dc, card);
        }

        if (card.get(:selectable) as Boolean) {
            drawSelectHint(dc);
        }
    }

    private function drawFloorCard(dc as Graphics.Dc, card as Dictionary) as Void {
        var centerX = dc.getWidth() / 2;
        var titleY = dc.getHeight() / 3;
        var statusYOffset = -6;

        drawTitle(dc, centerX, titleY, card.get(:name) as String);

        var statusY = titleY + dc.getFontHeight(TITLE_FONT) + SECTION_GAP;
        drawFloorLightStatus(dc, centerX, statusY + statusYOffset, card.get(:lightSummary) as String);

        drawSensorSummary(dc, card, centerX);
    }

    private function drawFloorLightStatus(dc as Graphics.Dc, centerX as Number, y as Number,
                                          text as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(centerX, y, LABEL_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawAreaCard(dc as Graphics.Dc, card as Dictionary) as Void {
        var centerX = dc.getWidth() / 2;
        var titleY = dc.getHeight() / 3;

        var floor = card.get(:floor) as String or Null;

        if (floor != null) {
            var floorY = titleY - SECTION_GAP - dc.getFontHeight(SUBTITLE_FONT);
            drawFloorLabel(dc, centerX, floorY, floor);
        }

        drawTitle(dc, centerX, titleY, card.get(:name) as String);

        var lightSummary = card.get(:lightSummary) as HomeSession.LightSummary or Null;

        if (lightSummary != null) {
            var indicatorsY = titleY + dc.getFontHeight(TITLE_FONT) + SECTION_GAP;
            drawLightIndicators(dc, centerX, indicatorsY, lightSummary);
        }

        drawSensorSummary(dc, card, centerX);
    }

    private function drawFloorLabel(dc as Graphics.Dc, centerX as Number, y as Number,
                                    text as String) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawText(centerX, y, SUBTITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTitle(dc as Graphics.Dc, centerX as Number, y as Number,
                               text as String) as Void {
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(centerX, y, TITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // An indicator per light: filled yellow when on, filled gray when
    // available-but-off, an outline when unavailable. The row is centered on centerX.
    private function drawLightIndicators(dc as Graphics.Dc, centerX as Number, y as Number,
                                         lightSummary as HomeSession.LightSummary) as Void {
        var onCount = lightSummary.get(:on) as Number;
        var availableCount = lightSummary.get(:available) as Number;
        var totalCount = availableCount + (lightSummary.get(:unavailable) as Number);

        var rowWidth = (totalCount - 1) * LIGHT_INDICATOR_SPACING;
        var startX = centerX - rowWidth / 2;
        var centerY = y + LIGHT_INDICATOR_RADIUS;

        for (var i = 0; i < totalCount; i++) {
            var x = startX + i * LIGHT_INDICATOR_SPACING;

            if (i < onCount) {
                drawFilledLightIndicator(dc, x, centerY, Graphics.COLOR_YELLOW);
            } else if (i < availableCount) {
                drawFilledLightIndicator(dc, x, centerY, Graphics.COLOR_DK_GRAY);
            } else {
                drawOutlinedLightIndicator(dc, x, centerY);
            }
        }
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

    // Temperature and humidity share the lower third, side by side; any other
    // deviceClass drops to its own row beneath them.
    private function drawSensorSummary(dc as Graphics.Dc, card as Dictionary,
                                       centerX as Number) as Void {
        var summary = card.get(:sensorSummary) as Array<Dictionary> or Null;

        if (summary == null) {
            return;
        }

        var baseY = 2 * dc.getHeight() / 3;
        var extraRowY = baseY + dc.getFontHeight(LABEL_FONT) + SUMMARY_LINE_GAP;

        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);

        for (var i = 0; i < summary.size(); i++) {
            var entry = summary[i];
            var deviceClass = entry.get(:device_class) as String or Null;
            var reading = entry.get(:reading) as String;

            var x = centerX;
            var y = extraRowY;

            if ("temperature".equals(deviceClass)) {
                x = dc.getWidth() / 3;
                y = baseY;
            } else if ("humidity".equals(deviceClass)) {
                x = 2 * dc.getWidth() / 3;
                y = baseY;
            }

            dc.drawText(x, y, LABEL_FONT, reading, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawSelectHint(dc as Graphics.Dc) as Void {
        var hint = WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource;

        dc.drawBitmap(
            system_loc__hint_button_right_top.x,
            system_loc__hint_button_right_top.y,
            hint
        );
    }

    private function useAntiAlias(dc as Graphics.Dc, enabled as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(enabled);
        }
    }
}
