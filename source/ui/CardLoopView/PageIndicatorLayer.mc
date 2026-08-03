import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// The page indicators on their own transparent layer, painted above the card so
// the fan can slide and crossfade without repainting the card.
class PageIndicatorLayer {
    private const PAGE_INDICATOR_INSET = 8;
    private const MAX_PAGE_INDICATORS = 5;
    private const LEFT_ANGLE = Math.PI;

    private const INACTIVE_COLOR = Graphics.COLOR_DK_GRAY;

    private var _layer as WatchUi.Layer;
    private var _pageIndicatorRadius as Number;
    private var _pageOverflowRadius as Number;
    private var _pageIndicatorSpacing as Number;

    function initialize() {
        _layer = new WatchUi.Layer(null);

        var dimensions = WatchUi.loadResource(Rez.JsonData.PageIndicatorDimensions) as Dictionary;
        _pageIndicatorRadius = dimensions.get("radius") as Number;
        _pageOverflowRadius = dimensions.get("overflowRadius") as Number;
        _pageIndicatorSpacing = dimensions.get("spacing") as Number;
    }

    function getLayer() as WatchUi.Layer {
        return _layer;
    }

    function setLocation(x as Number, y as Number) as Void {
        _layer.setLocation(x, y);
    }

    function setVisible(visible as Boolean) as Void {
        _layer.setVisible(visible);
    }

    function draw(currentIndex as Number, pageCount as Number, crossfadeFraction as Float,
                  fromIndex as Number) as Void {
        var dc = _layer.getDc();

        if (dc == null) {
            return;
        }

        dc.setColor(system_color_dark__text.color, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        drawPagination(dc, currentIndex, pageCount, crossfadeFraction, fromIndex);
    }

    private function drawPagination(dc as Graphics.Dc, currentIndex as Number, pageCount as Number,
                                    crossfadeFraction as Float, fromIndex as Number) as Void {
        var window = pageWindow(pageCount, currentIndex);
        var visibleCount = window.get(:count) as Number;
        var radius = (dc.getWidth() / 2 - PAGE_INDICATOR_INSET - _pageIndicatorRadius).toFloat();
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        var angleStep = _pageIndicatorSpacing / radius;

        if (window.get(:moreBefore) as Boolean) {
            drawOverflowIndicator(dc, fanAngle(-1, visibleCount, angleStep), centerX, centerY, radius);
        }

        var start = window.get(:start) as Number;

        for (var i = 0; i < visibleCount; i++) {
            var page = start + i;
            drawPageIndicator(dc, fanAngle(i, visibleCount, angleStep), centerX, centerY, radius,
                              page, currentIndex, fromIndex, crossfadeFraction);
        }

        if (window.get(:moreAfter) as Boolean) {
            drawOverflowIndicator(dc, fanAngle(visibleCount, visibleCount, angleStep),
                                  centerX, centerY, radius);
        }
    }

    private function fanAngle(i as Number, visibleCount as Number, angleStep as Float) as Float {
        return LEFT_ANGLE - (i - (visibleCount - 1) / 2.0) * angleStep;
    }

    private function pageWindow(pageCount as Number, currentIndex as Number) as Dictionary {
        if (pageCount <= MAX_PAGE_INDICATORS) {
            return {
                :start => 0,
                :count => pageCount,
                :moreBefore => false,
                :moreAfter => false
            };
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

    private function computePointOnCircle(angle as Float, centerX as Number, centerY as Number,
                                          radius as Float) as Array<Number> {
        return [
            centerX + Math.round(radius * Math.cos(angle)).toNumber(),
            centerY + Math.round(radius * Math.sin(angle)).toNumber()
        ];
    }

    private function drawPageIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                       centerY as Number, radius as Float, page as Number,
                                       currentIndex as Number, fromIndex as Number,
                                       crossfadeFraction as Float) as Void {
        var point = computePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        useAntiAlias(dc, true);

        if (page == currentIndex) {
            dc.setColor(lerpColor(INACTIVE_COLOR, system_color_dark__text.color, crossfadeFraction),
                        system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);

            return;
        }

        if (page == fromIndex && crossfadeFraction < 1.0) {
            dc.setColor(lerpColor(system_color_dark__text.color, INACTIVE_COLOR, crossfadeFraction),
                        system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);

            return;
        }

        useAntiAlias(dc, false);
        dc.setColor(INACTIVE_COLOR, system_color_dark__background.background);
        dc.drawCircle(x, y, _pageIndicatorRadius);
    }

    private function drawOverflowIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                           centerY as Number, radius as Float) as Void {
        var point = computePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        useAntiAlias(dc, false);
        dc.setColor(INACTIVE_COLOR, system_color_dark__background.background);
        dc.fillCircle(x, y, _pageOverflowRadius);
    }

    private function lerpColor(from as Number, to as Number, fraction as Float) as Number {
        var fromRed = (from >> 16) & 0xFF;
        var fromGreen = (from >> 8) & 0xFF;
        var fromBlue = from & 0xFF;

        var toRed = (to >> 16) & 0xFF;
        var toGreen = (to >> 8) & 0xFF;
        var toBlue = to & 0xFF;

        var red = (fromRed + (toRed - fromRed) * fraction).toNumber();
        var green = (fromGreen + (toGreen - fromGreen) * fraction).toNumber();
        var blue = (fromBlue + (toBlue - fromBlue) * fraction).toNumber();

        return (red << 16) | (green << 8) | blue;
    }

    private function useAntiAlias(dc as Graphics.Dc, enabled as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(enabled);
        }
    }
}
