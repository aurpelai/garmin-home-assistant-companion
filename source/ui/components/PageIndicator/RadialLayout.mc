import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

class RadialLayout {
    private const MAX_PAGE_INDICATORS = 5;
    private const START_ANGLE = Math.PI;

    private var _centerX as Number;
    private var _centerY as Number;
    private var _radiusStart as Float;
    private var _radiusEnd as Float;
    private var _spacing as Number;
    private var _slideOutDuration as Float;
    public var radius as Float;

    function initialize(centerX as Number, centerY as Number, radiusStart as Float, radiusEnd as Float,
                        spacing as Number, slideOutDuration as Float) {
        _centerX = centerX;
        _centerY = centerY;
        _radiusStart = radiusStart;
        _radiusEnd = radiusEnd;
        _spacing = spacing;
        _slideOutDuration = slideOutDuration;
        radius = radiusStart;
    }

    function reset() as Void {
        radius = _radiusStart;
    }

    function startDismiss(onHidden as (Method() as Void)) as Void {
        WatchUi.animate(
            self,
            :radius,
            WatchUi.ANIM_TYPE_LINEAR,
            _radiusStart,
            _radiusEnd,
            _slideOutDuration,
            onHidden
        );
    }

    function draw(dc as Graphics.Dc, indicator as PageIndicator, currentPage as Number, pageCount as Number) as Void {
        if (pageCount <= MAX_PAGE_INDICATORS) {
            drawWindow(dc, indicator, 0, pageCount, false, false);

            return;
        }

        if (currentPage <= MAX_PAGE_INDICATORS - 1) {
            drawWindow(dc, indicator, 0, MAX_PAGE_INDICATORS, false, true);

            return;
        }

        if (currentPage >= pageCount - MAX_PAGE_INDICATORS) {
            drawWindow(dc, indicator, pageCount - MAX_PAGE_INDICATORS, MAX_PAGE_INDICATORS, true, false);

            return;
        }

        drawWindow(dc, indicator, currentPage - MAX_PAGE_INDICATORS / 2, MAX_PAGE_INDICATORS, true, true);
    }

    private function drawWindow(dc as Graphics.Dc, indicator as PageIndicator, start as Number,
                                count as Number, moreBefore as Boolean, moreAfter as Boolean) as Void {
        var angleStep = _spacing / _radiusStart;

        if (moreBefore) {
            var point = calculatePointOnCircle(calculateFanAngle(-1, count, angleStep));
            indicator.drawOverflowDot(dc, point[0], point[1]);
        }

        for (var i = 0; i < count; i++) {
            var point = calculatePointOnCircle(calculateFanAngle(i, count, angleStep));
            indicator.drawDot(dc, point[0], point[1], start + i);
        }

        if (moreAfter) {
            var point = calculatePointOnCircle(calculateFanAngle(count, count, angleStep));
            indicator.drawOverflowDot(dc, point[0], point[1]);
        }
    }

    private function calculateFanAngle(i as Number, visibleIndicatorCount as Number, angleStep as Float) as Float {
        return START_ANGLE - (i - (visibleIndicatorCount - 1) / 2.0) * angleStep;
    }

    private function calculatePointOnCircle(angle as Float) as Array<Float> {
        return [
            (_centerX + radius * Math.cos(angle)).toFloat(),
            (_centerY + radius * Math.sin(angle)).toFloat()
        ];
    }
}
