import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Draws one card of the top-level loop. Fonts, colors, and the select-key hint
// come from the device's SDK personality (System 6 / API 5.0.0), so they track
// the watch theme instead of being hand-picked.
class CardRenderer {
    private const TITLE_FONT = prompt_font__body_no_title.font;
    private const FLOOR_LABEL_FONT = prompt_font__title.font;
    private const SUMMARY_FONT = prompt_font__body_with_title.font;

    private const SECTION_GAP = 16;
    private const SUMMARY_LINE_GAP = 8;

    private const DOT_RADIUS = 6;
    private const DOT_SPACING = DOT_RADIUS * 3;
    private const UNAVAILABLE_PEN = 2;

    private const PAGE_DOT_RADIUS = 4;
    private const PAGE_OVERFLOW_RADIUS = 2;
    private const PAGE_DOT_SPACING = 18;
    private const PAGE_DOT_INSET = 8;
    private const MAX_PAGE_DOTS = 5;

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

        drawTitle(dc, centerX, titleY, card.get(:name) as String);
        drawSensorSummary(dc, card, centerX);
    }

    private function drawAreaCard(dc as Graphics.Dc, card as Dictionary) as Void {
        var centerX = dc.getWidth() / 2;
        var titleY = dc.getHeight() / 3;

        var floor = card.get(:floor) as String or Null;

        if (floor != null) {
            var floorY = titleY - SECTION_GAP - dc.getFontHeight(FLOOR_LABEL_FONT);
            drawFloorLabel(dc, centerX, floorY, floor);
        }

        drawTitle(dc, centerX, titleY, card.get(:name) as String);

        var lightSummary = card.get(:lightSummary) as Dictionary<Symbol, Number> or Null;

        if (lightSummary != null) {
            var dotsY = titleY + dc.getFontHeight(TITLE_FONT) + SECTION_GAP;
            drawLightDots(dc, centerX, dotsY, lightSummary);
        }

        drawSensorSummary(dc, card, centerX);
    }

    private function drawFloorLabel(dc as Graphics.Dc, centerX as Number, y as Number,
                                    text as String) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__text.background);
        dc.drawText(centerX, y, FLOOR_LABEL_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTitle(dc as Graphics.Dc, centerX as Number, y as Number,
                               text as String) as Void {
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(centerX, y, TITLE_FONT, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A dot per light: filled yellow when on, filled gray when available-but-off,
    // an outline when unavailable. The row is centered on centerX.
    private function drawLightDots(dc as Graphics.Dc, centerX as Number, y as Number,
                                   lightSummary as Dictionary<Symbol, Number>) as Void {
        var onCount = lightSummary.get(:on) as Number;
        var availableCount = lightSummary.get(:available) as Number;
        var totalCount = availableCount + (lightSummary.get(:unavailable) as Number);

        var rowWidth = (totalCount - 1) * DOT_SPACING;
        var startX = centerX - rowWidth / 2;
        var centerY = y + DOT_RADIUS;

        for (var i = 0; i < totalCount; i++) {
            var dotX = startX + i * DOT_SPACING;

            if (i < onCount) {
                fillDot(dc, dotX, centerY, Graphics.COLOR_YELLOW);
            } else if (i < availableCount) {
                fillDot(dc, dotX, centerY, Graphics.COLOR_DK_GRAY);
            } else {
                outlineDot(dc, dotX, centerY);
            }
        }
    }

    private function fillDot(dc as Graphics.Dc, x as Number, y as Number, color as Number) as Void {
        dc.setColor(color, system_color_dark__background.background);
        dc.fillCircle(x, y, DOT_RADIUS);
    }

    private function outlineDot(dc as Graphics.Dc, x as Number, y as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.setPenWidth(UNAVAILABLE_PEN);
        dc.drawCircle(x, y, DOT_RADIUS);
        dc.setPenWidth(1);
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

    // Page dots ride a vertical arc down the left bezel. When the pages outrun
    // MAX_PAGE_DOTS, the window slides and a small overflow dot marks the
    // clipped end(s).
    private function drawPagination(dc as Graphics.Dc, pageCount as Number,
                                    currentIndex as Number) as Void {
        if (pageCount <= 1) {
            return;
        }

        var window = pageWindow(pageCount, currentIndex);
        var visibleCount = window.get(:count) as Number;
        var arcRadius = (dc.getWidth() / 2 - PAGE_DOT_INSET - PAGE_DOT_RADIUS).toFloat();
        var centerY = dc.getHeight() / 2;
        var top = (dc.getHeight() - ((visibleCount - 1) * PAGE_DOT_SPACING)) / 2;

        if (window.get(:moreBefore) as Boolean) {
            drawOverflowDot(dc, top - PAGE_DOT_SPACING, centerY, arcRadius);
        }

        var start = window.get(:start) as Number;

        for (var i = 0; i < visibleCount; i++) {
            var y = top + i * PAGE_DOT_SPACING;
            var x = arcX(y, centerY, arcRadius);
            drawPageDot(dc, x, y, start + i == currentIndex);
        }

        if (window.get(:moreAfter) as Boolean) {
            drawOverflowDot(dc, top + MAX_PAGE_DOTS * PAGE_DOT_SPACING, centerY, arcRadius);
        }
    }

    // The slice of pages to show and which ends are clipped, keeping the current
    // page inside the window.
    private function pageWindow(pageCount as Number, currentIndex as Number) as Dictionary {
        if (pageCount <= MAX_PAGE_DOTS) {
            return { :start => 0, :count => pageCount, :moreBefore => false, :moreAfter => false };
        }

        if (currentIndex <= MAX_PAGE_DOTS - 1) {
            return {
                :start => 0,
                :count => MAX_PAGE_DOTS,
                :moreBefore => false,
                :moreAfter => true
            };
        }

        if (currentIndex >= pageCount - MAX_PAGE_DOTS) {
            return {
                :start => pageCount - MAX_PAGE_DOTS,
                :count => MAX_PAGE_DOTS,
                :moreBefore => true,
                :moreAfter => false
            };
        }

        return {
            :start => currentIndex - MAX_PAGE_DOTS / 2,
            :count => MAX_PAGE_DOTS,
            :moreBefore => true,
            :moreAfter => true
        };
    }

    private function drawPageDot(dc as Graphics.Dc, x as Number, y as Number,
                                 isCurrent as Boolean) as Void {
        if (isCurrent) {
            dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
            dc.fillCircle(x, y, PAGE_DOT_RADIUS);
            return;
        }

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.drawCircle(x, y, PAGE_DOT_RADIUS);
        useAntiAlias(dc, true);
    }

    private function drawOverflowDot(dc as Graphics.Dc, y as Number, centerY as Number,
                                     arcRadius as Float) as Void {
        var x = arcX(y, centerY, arcRadius) + (PAGE_DOT_RADIUS - PAGE_OVERFLOW_RADIUS) / 2;

        useAntiAlias(dc, false);
        dc.setColor(Graphics.COLOR_DK_GRAY, system_color_dark__background.background);
        dc.fillCircle(x, y, PAGE_OVERFLOW_RADIUS);
        useAntiAlias(dc, true);
    }

    // x on a circle of the given radius (centered on the left edge) for a given y,
    // so the dots trace the bezel's curve.
    private function arcX(y as Number, centerY as Number, radius as Float) as Number {
        var dy = (y - centerY).toFloat();
        var dx = Math.sqrt(radius * radius - dy * dy);

        return (PAGE_DOT_INSET + radius - dx).toNumber();
    }

    private function drawSelectHint(dc as Graphics.Dc) as Void {
        var hint = WatchUi.loadResource(Rez.Drawables.SelectHint) as BitmapResource;

        dc.drawBitmap2(
            system_loc__hint_button_right_top.x,
            system_loc__hint_button_right_top.y,
            hint,
            null
        );
    }

    // Outline (non-filled) circles alias badly on real hardware, so anti-alias
    // is switched off around them and restored after — not incidental, keep it.
    private function useAntiAlias(dc as Graphics.Dc, enabled as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(enabled);
        }
    }
}
