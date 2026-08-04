import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

enum PageIndicatorState {
    PAGE_INDICATOR_HIDDEN,
    PAGE_INDICATOR_VISIBLE
}

class PageIndicator {
    private const ANIMATION_DURATION = 0.1;
    private const VISIBLE_DURATION_MS = 1800;
    private const FADE_DURATION = 0.05;

    private const LEFT_ANGLE = Math.PI;

    private const INACTIVE_INDICATOR_COLOR = Graphics.COLOR_LT_GRAY;
    private const PAGE_INDICATOR_INSET = 8;
    private const MAX_PAGE_INDICATORS = 5;
    private const MIN_PAGE_INDICATORS = 3;

    private var _pageIndicatorRadius as Number;
    private var _pageOverflowRadius as Number;
    private var _pageIndicatorSpacing as Number;

    private var _layer as WatchUi.Layer;
    private var _state as PageIndicatorState;

    private var _pageCount as Number;
    private var _currentPage as Number;

    private var _timer as Timer.Timer;
    public var _animationProgress as Float;
    public var _fadeProgress as Float;


    function initialize(pageCount as Number) {
        _layer = new WatchUi.Layer(null);
        _pageCount = pageCount;

        var dimensions = WatchUi.loadResource(Rez.JsonData.PageIndicatorDimensions) as Dictionary;
        _pageIndicatorRadius = dimensions.get("radius") as Number;
        _pageOverflowRadius = dimensions.get("overflowRadius") as Number;
        _pageIndicatorSpacing = dimensions.get("spacing") as Number;

        _timer = new Timer.Timer();
        _state = PAGE_INDICATOR_HIDDEN;

        _animationProgress = 0.0;
        _fadeProgress = 1.0;
        _currentPage = 0;
    }

    function onParentViewHide() as Void {
        WatchUi.cancelAllAnimations();
        _timer.stop();
        hideIndicator();
    }

    function onHideStart() as Void {
        WatchUi.animate(self, :_animationProgress, WatchUi.ANIM_TYPE_LINEAR, _animationProgress, 1.0,
                        ANIMATION_DURATION, method(:hideIndicator));
    }

    function draw() as Void {
        var dc = _layer.getDc();

        if (dc == null) {
            return;
        }

        var currentPageWindow = getCurrentPageWindow();
        var visibleIndicatorCount = currentPageWindow.get(:count) as Number;

        var baseRadius = (dc.getWidth() / 2 - PAGE_INDICATOR_INSET - _pageIndicatorRadius).toFloat();
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        // The angular step stays keyed to the base radius so the fan holds its
        // shape as it expands past the bezel rather than narrowing.
        var radius = baseRadius + _animationProgress * (centerX + _pageIndicatorRadius - baseRadius);
        var angleStep = _pageIndicatorSpacing / baseRadius;

        clear();

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        if (currentPageWindow.get(:moreBefore) as Boolean) {
            drawOverflowIndicator(dc, calculateFanAngle(-1, visibleIndicatorCount, angleStep), centerX, centerY, radius);
        }

        var start = currentPageWindow.get(:start) as Number;

        for (var i = 0; i < visibleIndicatorCount; i++) {
            var page = start + i;
            drawPageIndicator(dc, calculateFanAngle(i, visibleIndicatorCount, angleStep), centerX, centerY, radius,
                              page);
        }

        if (currentPageWindow.get(:moreAfter) as Boolean) {
            drawOverflowIndicator(dc, calculateFanAngle(visibleIndicatorCount, visibleIndicatorCount, angleStep),
                                  centerX, centerY, radius);
        }

    }

    private function drawPageIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                       centerY as Number, radius as Float, page as Number) as Void {
        var point = calculatePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        if (page == _currentPage) {
            dc.setColor(lerpColor(INACTIVE_INDICATOR_COLOR, system_color_dark__text.color, _fadeProgress),
                        system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);

            return;
        }

        if (page == _currentPage && _fadeProgress < 1.0) {
            dc.setColor(lerpColor(system_color_dark__text.color, INACTIVE_INDICATOR_COLOR, _fadeProgress),
                        system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);

            return;
        }

        dc.setColor(INACTIVE_INDICATOR_COLOR, system_color_dark__background.background);
        dc.drawCircle(x, y, _pageIndicatorRadius);
    }

    private function drawOverflowIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                           centerY as Number, radius as Float) as Void {
        var point = calculatePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        dc.setColor(INACTIVE_INDICATOR_COLOR, system_color_dark__background.background);
        dc.fillCircle(x, y, _pageOverflowRadius);
    }

    function getLayer() as WatchUi.Layer {
        return _layer;
    }

    function clear() as Void {
        var dc = _layer.getDc();

        if (dc == null) {
            return;
        }

        dc.setColor(system_color_dark__text.color, Graphics.COLOR_TRANSPARENT);
        dc.clear();
    }

    function isVisible() as Boolean {
        return _state == PAGE_INDICATOR_VISIBLE;
    }

    function showIndicator() as Void {
        _state = _pageCount < MIN_PAGE_INDICATORS
            ? PAGE_INDICATOR_HIDDEN
            : PAGE_INDICATOR_VISIBLE;

        if (!isVisible()) {
            return;
        }

        WatchUi.cancelAllAnimations();
        _timer.stop();

        _animationProgress = 0.0;
        _fadeProgress = 1.0;
        WatchUi.requestUpdate();

        _timer.start(method(:onHideStart), VISIBLE_DURATION_MS, false);
    }

    function hideIndicator() as Void {
        _state = PAGE_INDICATOR_HIDDEN;
        clear();
    }

    function updateIndex(index as Number) as Void {
        // TODO check overflow
        _currentPage = index;

        showIndicator();
        draw();
        fadeActiveDot();
    }

    private function fadeActiveDot() as Void {
        _fadeProgress = 0.0;
        WatchUi.animate(self, :_fadeProgress, WatchUi.ANIM_TYPE_LINEAR, 0.0, 1.0,
                        FADE_DURATION, null);
    }

    private function calculateFanAngle(i as Number, visibleIndicatorCount as Number, angleStep as Float) as Float {
        return LEFT_ANGLE - (i - (visibleIndicatorCount - 1) / 2.0) * angleStep;
    }

    private function calculatePointOnCircle(angle as Float, centerX as Number, centerY as Number,
                                          radius as Float) as Array<Float> {
        return [
            (centerX + radius * Math.cos(angle)).toFloat(),
            (centerY + radius * Math.sin(angle)).toFloat()
        ];
    }

    private function getCurrentPageWindow() as Dictionary {
        if (_pageCount <= MAX_PAGE_INDICATORS) {
            return {
                :start => 0,
                :count => _pageCount,
                :moreBefore => false,
                :moreAfter => false
            };
        }

        if (_currentPage <= MAX_PAGE_INDICATORS - 1) {
            return {
                :start => 0,
                :count => MAX_PAGE_INDICATORS,
                :moreBefore => false,
                :moreAfter => true
            };
        }

        if (_currentPage >= _pageCount - MAX_PAGE_INDICATORS) {
            return {
                :start => _pageCount - MAX_PAGE_INDICATORS,
                :count => MAX_PAGE_INDICATORS,
                :moreBefore => true,
                :moreAfter => false
            };
        }

        return {
            :start => _currentPage - MAX_PAGE_INDICATORS / 2,
            :count => MAX_PAGE_INDICATORS,
            :moreBefore => true,
            :moreAfter => true
        };
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
}
