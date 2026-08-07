import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Draws one card of the top-level loop. Fonts, colors, and the select-key hint
// come from the device's SDK personality (System 6 / API 5.0.0), so they track
// the watch theme instead of being hand-picked.
class CardRenderer {
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
        :face => ["RobotoCondensedRegular", "RobotoRegular"],
        :size => FONT_SIZES.get("small") as Number
    }) as Graphics.VectorFont;

    private const LABEL_FONT = Graphics.getVectorFont({
        :face => ["RobotoCondensedRegular", "RobotoRegular"],
        :size => FONT_SIZES.get("medium") as Number
    }) as Graphics.VectorFont;

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
        var titleY = dc.getHeight() * 3 / COLUMN_COUNT;
        var subtitle = card.get(:zone) as String or Null;

        if (subtitle != null) {
            var subtitleY = dc.getHeight() * 2 / COLUMN_COUNT;
            drawSubtitle(
                dc,
                centerX,
                subtitleY,
                subtitle
            );
        }

        drawTitle(
            dc,
            centerX,
            titleY,
            card.get(:name) as String
        );

        var statusY = dc.getHeight() / 2 - LIGHT_INDICATOR_RADIUS;
        drawFloorLightStatus(
            dc,
            centerX,
            statusY,
            card.get(:lightSummary) as String
        );
        drawSensorEntities(
            dc,
            card,
            centerX
        );
    }

    private function drawAreaCard(dc as Graphics.Dc, card as Dictionary) as Void {
        var centerX = dc.getWidth() / 2;
        var titleY = dc.getHeight() * 3 / COLUMN_COUNT;
        var subtitle = card.get(:floor) as String or Null;

        if (subtitle != null) {
            var subtitleY = dc.getHeight() * 2 / COLUMN_COUNT;
            drawSubtitle(
                dc,
                centerX,
                subtitleY,
                subtitle
            );
        }

        drawTitle(
            dc,
            centerX,
            titleY,
            card.get(:name) as String
        );

        var lightSummary = card.get(:lightSummary) as HomeSession.LightSummary or Null;

        if (lightSummary != null) {
            var indicatorsY = dc.getHeight() / 2 - LIGHT_INDICATOR_RADIUS;
            drawLightIndicators(
                dc,
                centerX,
                indicatorsY,
                lightSummary
            );
        }

        drawSensorEntities(
            dc,
            card,
            centerX
        );
    }

    private function drawTitle(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        useAntiAlias(dc, true);
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(
            x,
            y,
            TITLE_FONT,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawSubtitle(dc as Graphics.Dc, x as Number, y as Number, text as String) as Void {
        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawText(
            x,
            y,
            SUBTITLE_FONT,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawFloorLightStatus(dc as Graphics.Dc, centerX as Number, y as Number, text as String) as Void {
        useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(
            centerX,
            y,
            SUBTITLE_FONT,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawLightIndicators(dc as Graphics.Dc, x as Number, y as Number, lightSummary as HomeSession.LightSummary) as Void {
        var onCount = lightSummary.get(:on) as Number;
        var availableCount = lightSummary.get(:available) as Number;
        var totalCount = availableCount + (lightSummary.get(:unavailable) as Number);

        var rowWidth = (totalCount - 1) * LIGHT_INDICATOR_SIZE;
        var firstX = x - rowWidth / 2;
        var centerY = y + LIGHT_INDICATOR_RADIUS;

        for (var i = 0; i < totalCount; i++) {
            var thisX = firstX + i * LIGHT_INDICATOR_SIZE;

            if (i < onCount) {
                drawFilledLightIndicator(
                    dc,
                    thisX,
                    centerY,
                    Graphics.COLOR_YELLOW
                );
            } else if (i < availableCount) {
                drawFilledLightIndicator(
                    dc,
                    thisX,
                    centerY,
                    Graphics.COLOR_DK_GRAY
                );
            } else {
                drawOutlinedLightIndicator(
                    dc,
                    thisX,
                    centerY
                );
            }
        }
    }

    private function drawFilledLightIndicator(dc as Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        useAntiAlias(dc, true);
        dc.setColor(color, system_color_dark__background.background);
        dc.fillCircle(
            x,
            y,
            LIGHT_INDICATOR_RADIUS
        );
    }

    private function drawOutlinedLightIndicator(dc as Graphics.Dc, x as Number, y as Number) as Void {
        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.drawCircle(
            x,
            y,
            LIGHT_INDICATOR_RADIUS
        );
    }

    private function drawSensorEntities(dc as Graphics.Dc, card as Dictionary, centerX as Number) as Void {
        var summary = card.get(:sensorSummary) as Array<Dictionary> or Null;

        if (summary == null) {
            return;
        }

        for (var i = 0; i < summary.size(); i++) {
            var entity = summary[i];
            var deviceClass = entity.get(:device_class) as String or Null;

            if ("temperature".equals(deviceClass)) {
                drawTemperature(dc, entity);
                continue;
            }

             if ("humidity".equals(deviceClass)) {
                drawHumidity(dc, entity);
                continue;
            }

            if ("illuminance".equals(deviceClass)) {
                drawIlluminance(dc, entity);
                continue;
            }
        }
    }

    private function drawTemperature(dc as Graphics.Dc, entity as Dictionary) as Void {
        var x = dc.getWidth() * 4 / COLUMN_COUNT;
        var y = dc.getHeight() * 8 / COLUMN_COUNT;
        var reading = entity.get(:reading) as String;
        var textWidth = dc.getTextWidthInPixels(reading, LABEL_FONT);
        var textHeight = dc.getFontHeight(LABEL_FONT);

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawRoundedRectangle(x - BOX_HORIZONTAL_PADDING - (textWidth / 2), y - BOX_VERTICAL_PADDING, textWidth + (2 * BOX_HORIZONTAL_PADDING), textHeight + (2 * BOX_VERTICAL_PADDING), BOX_BORDER_RADIUS);

        useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(
            x,
            y,
            LABEL_FONT,
            reading,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawHumidity(dc as Graphics.Dc, entity as Dictionary) as Void {
        var x = dc.getWidth() * 8 / COLUMN_COUNT;
        var y = dc.getHeight() * 8 / COLUMN_COUNT;
        var reading = entity.get(:reading) as String;
        var textWidth = dc.getTextWidthInPixels(reading, LABEL_FONT);
        var textHeight = dc.getFontHeight(LABEL_FONT);

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawRoundedRectangle(x - BOX_HORIZONTAL_PADDING - (textWidth / 2), y - BOX_VERTICAL_PADDING, textWidth + (2 * BOX_HORIZONTAL_PADDING), textHeight + (2 * BOX_VERTICAL_PADDING), BOX_BORDER_RADIUS);

        useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(
            x,
            y,
            LABEL_FONT,
            reading,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawIlluminance(dc as Graphics.Dc, entity as Dictionary) as Void {
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() * 10 / COLUMN_COUNT;
        var reading = entity.get(:reading) as String;
        var textWidth = dc.getTextWidthInPixels(reading, LABEL_FONT);
        var textHeight = dc.getFontHeight(LABEL_FONT);

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawRoundedRectangle(x - BOX_HORIZONTAL_PADDING - (textWidth / 2), y - BOX_VERTICAL_PADDING, textWidth + (2 * BOX_HORIZONTAL_PADDING), textHeight + (2 * BOX_VERTICAL_PADDING), BOX_BORDER_RADIUS);

        useAntiAlias(dc, true);
        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);
        dc.drawText(
            x,
            y,
            LABEL_FONT,
            reading,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawSelectHint(dc as Graphics.Dc) as Void {
        var hint = WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource;

        useAntiAlias(dc, true);
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
