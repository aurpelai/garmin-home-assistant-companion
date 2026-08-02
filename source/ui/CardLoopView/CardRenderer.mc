import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Draws one card of the top-level loop. Fonts, colors, and the select-key hint
// come from the device's SDK personality (System 6 / API 5.0.0), so they track
// the watch theme instead of being hand-picked.
class CardRenderer {
    private const TITLE_FONT = Graphics.FONT_SMALL;
    private const SUBTITLE_FONT = Graphics.FONT_XTINY;
    private const SUMMARY_FONT = Graphics.FONT_GLANCE;

    private const SECTION_GAP = 16;
    private const SUMMARY_LINE_GAP = 8;

    private const LIGHT_INDICATOR_RADIUS = 6;
    private const LIGHT_INDICATOR_SPACING = LIGHT_INDICATOR_RADIUS * 3;

    private const PAGE_INDICATOR_RADIUS = 4;
    private const PAGE_OVERFLOW_RADIUS = 2;
    private const PAGE_INDICATOR_INSET = 8;
    private const PAGE_INDICATOR_SPACING = 16;
    private const MAX_PAGE_INDICATORS = 5;
    private const LEFT_ANGLE = Math.PI;

    function drawCard(dc as Graphics.Dc, card as Dictionary, pageCount as Number,
                      pageIndex as Number) as Void {
        useAntiAlias(dc, true);

        if (card.get(:type) == :floor) {
            drawFloorCard(dc, card);
        } else {
            drawAreaCard(dc, card);
        }

        drawPagination(dc, pageCount, pageIndex);
        drawSelectHint(dc);
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
        dc.drawText(centerX, y, SUMMARY_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
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

        var lightSummary = card.get(:lightSummary) as Dictionary<Symbol, Number> or Null;

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
                                         lightSummary as Dictionary<Symbol, Number>) as Void {
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
    // kind drops to its own row beneath them.
    private function drawSensorSummary(dc as Graphics.Dc, card as Dictionary,
                                       centerX as Number) as Void {
        var summary = card.get(:sensorSummary) as Array<Dictionary> or Null;

        if (summary == null) {
            return;
        }

        var baseY = 2 * dc.getHeight() / 3;
        var extraRowY = baseY + dc.getFontHeight(SUMMARY_FONT) + SUMMARY_LINE_GAP;

        dc.setColor(Graphics.COLOR_LT_GRAY, system_color_dark__text.background);

        for (var i = 0; i < summary.size(); i++) {
            var entry = summary[i];
            var kind = entry.get(:kind) as String or Null;
            var reading = entry.get(:reading) as String;

            var x = centerX;
            var y = extraRowY;

            if ("temperature".equals(kind)) {
                x = dc.getWidth() / 3;
                y = baseY;
            } else if ("humidity".equals(kind)) {
                x = 2 * dc.getWidth() / 3;
                y = baseY;
            }

            dc.drawText(x, y, SUMMARY_FONT, reading, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Page indicators sit on the display's circle, fanned around 9 o'clock by a
    // fixed angular step so they stay on the perimeter. The fan is centered on
    // LEFT_ANGLE for any count. When the pages outrun MAX_PAGE_INDICATORS, the
    // window slides and a small overflow indicator marks the clipped end(s).
    private function drawPagination(dc as Graphics.Dc, pageCount as Number,
                                    currentIndex as Number) as Void {
        if (pageCount <= 1) {
            return;
        }

        var window = pageWindow(pageCount, currentIndex);
        var visibleCount = window.get(:count) as Number;
        var radius = (dc.getWidth() / 2 - PAGE_INDICATOR_INSET - PAGE_INDICATOR_RADIUS).toFloat();
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        // Derive the angular step from a target pixel gap so indicators keep the
        // same on-screen spacing whatever the display's radius.
        var angleStep = PAGE_INDICATOR_SPACING / radius;

        if (window.get(:moreBefore) as Boolean) {
            drawOverflowIndicator(dc, fanAngle(-1, visibleCount, angleStep), centerX, centerY, radius);
        }

        var start = window.get(:start) as Number;

        for (var i = 0; i < visibleCount; i++) {
            drawPageIndicator(dc, fanAngle(i, visibleCount, angleStep), centerX, centerY, radius,
                              start + i == currentIndex);
        }

        if (window.get(:moreAfter) as Boolean) {
            drawOverflowIndicator(dc, fanAngle(visibleCount, visibleCount, angleStep),
                                  centerX, centerY, radius);
        }
    }

    // The angle of the indicator at fan position i (of visibleCount), stepped
    // from LEFT_ANGLE and centered on it. The step is subtracted so a rising i
    // runs top-to-bottom (sin grows downward in screen space). Positions -1 and
    // visibleCount fall one step past each end, where the overflow indicators sit.
    private function fanAngle(i as Number, visibleCount as Number, angleStep as Float) as Float {
        return LEFT_ANGLE - (i - (visibleCount - 1) / 2.0) * angleStep;
    }

    // The slice of pages to show and which ends are clipped, keeping the current
    // page inside the window.
    private function pageWindow(pageCount as Number, currentIndex as Number) as Dictionary {
        if (pageCount <= MAX_PAGE_INDICATORS) {
            return { :start => 0, :count => pageCount, :moreBefore => false, :moreAfter => false };
        }

        if (currentIndex <= MAX_PAGE_INDICATORS - 1) {
            return {
                :start => 0,
                :count => MAX_PAGE_INDICATORS,
                :moreBefore => false,
                :moreAfter => true
            };
        }

        if (currentIndex >= pageCount - MAX_PAGE_INDICATORS) {
            return {
                :start => pageCount - MAX_PAGE_INDICATORS,
                :count => MAX_PAGE_INDICATORS,
                :moreBefore => true,
                :moreAfter => false
            };
        }

        return {
            :start => currentIndex - MAX_PAGE_INDICATORS / 2,
            :count => MAX_PAGE_INDICATORS,
            :moreBefore => true,
            :moreAfter => true
        };
    }

    // The [x, y] pixel of a point at the given angle on the circle. Rounds to
    // the nearest pixel rather than truncating, so placement stays symmetric
    // about the center instead of biasing toward it.
    private function computePointOnCircle(angle as Float, centerX as Number, centerY as Number,
                                          radius as Float) as Array<Number> {
        return [
            centerX + Math.round(radius * Math.cos(angle)).toNumber(),
            centerY + Math.round(radius * Math.sin(angle)).toNumber()
        ];
    }

    private function drawPageIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                       centerY as Number, radius as Float,
                                       isCurrent as Boolean) as Void {
        var point = computePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        if (isCurrent) {
            useAntiAlias(dc, true);
            dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
            dc.fillCircle(x, y, PAGE_INDICATOR_RADIUS);
            return;
        }

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.drawCircle(x, y, PAGE_INDICATOR_RADIUS);
    }

    private function drawOverflowIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                           centerY as Number, radius as Float) as Void {
        var point = computePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.fillCircle(x, y, PAGE_OVERFLOW_RADIUS);
    }

    // drawBitmap, not drawBitmap2: some devices ship this hint as a palette
    // bitmap, which drawBitmap2 rejects ("Source must not use a color palette").
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
