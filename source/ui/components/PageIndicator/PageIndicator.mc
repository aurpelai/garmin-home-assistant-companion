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
    private const SLIDE_OUT_DURATION = 0.2;
    private const VISIBLE_DURATION_MS = 1800;
    private const INDICATOR_FADE_DURATION = 0.05;

    private const START_ANGLE = Math.PI;

    private const PAGE_INDICATOR_INSET = 8;
    private const MAX_PAGE_INDICATORS = 5;
    private const MIN_PAGE_INDICATORS = 3;

    private const ACTIVE_INDICATOR_COLOR_CHANNEL = 254; // NOTE: 255 causes Graphics.createColor to return -1 (transparent)
    private const INACTIVE_INDICATOR_COLOR_CHANNEL = 0;
    private const INACTIVE_INDICATOR_STROKE_COLOR = Graphics.COLOR_LT_GRAY;

    private var _pageIndicatorRadius as Number;
    private var _pageOverflowRadius as Number;
    private var _pageIndicatorSpacing as Number;
    public var _inactiveIndicatorColorChannel as Number;

    private var _radiusStart as Float;
    private var _radiusEnd as Float;
    public var _radius as Float;

    private var _layer as WatchUi.Layer;
    private var _state as PageIndicatorState;
    private var _timer as Timer.Timer;

    private var _pageCount as Number;
    private var _currentPage as Number;
    private var _previousPage as Number;

    function initialize(pageCount as Number) {
        _layer = new WatchUi.Layer(null);
        _state = PAGE_INDICATOR_HIDDEN;

        _pageCount = pageCount;
        _currentPage = 0;
        _previousPage = 0;

        var dimensions = WatchUi.loadResource(Rez.JsonData.PageIndicatorDimensions) as Dictionary;
        _pageIndicatorRadius = dimensions.get("radius") as Number;
        _pageOverflowRadius = dimensions.get("overflowRadius") as Number;
        _pageIndicatorSpacing = dimensions.get("spacing") as Number;

        var dc = _layer.getDc();
        _radiusStart = dc != null
            ? (dc.getWidth() / 2 - PAGE_INDICATOR_INSET - _pageIndicatorRadius).toFloat()
            : 0.0;
        _radius = _radiusStart;
        _radiusEnd = dc != null
            ? (dc.getWidth() / 2 + PAGE_INDICATOR_INSET + _pageIndicatorRadius).toFloat()
            : 0.0;

        _timer = new Timer.Timer();
        _inactiveIndicatorColorChannel = INACTIVE_INDICATOR_COLOR_CHANNEL;
    }

    function onParentViewHide() as Void {
        dismiss();
    }

    private function dismiss() as Void {
        WatchUi.cancelAllAnimations();
        _timer.stop();
        hideIndicator();
    }

    function onHideStart() as Void {
        WatchUi.animate(
            self,
            :_radius,
            WatchUi.ANIM_TYPE_LINEAR,
            _radiusStart,
            _radiusEnd,
            SLIDE_OUT_DURATION,
            method(:hideIndicator)
        );
    }

    private function onIndexUpdate() as Void {
        WatchUi.animate(
            self,
            :_inactiveIndicatorColorChannel,
            WatchUi.ANIM_TYPE_LINEAR,
            ACTIVE_INDICATOR_COLOR_CHANNEL,
            INACTIVE_INDICATOR_COLOR_CHANNEL,
            INDICATOR_FADE_DURATION,
            null
        );
    }

    function draw() as Void {
        var dc = _layer.getDc();

        if (dc == null) {
            return;
        }

        var currentPageWindow = getCurrentPageWindow();
        var visibleIndicatorCount = currentPageWindow.get(:count) as Number;

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var angleStep = _pageIndicatorSpacing / _radiusStart;

        clear();

        if (currentPageWindow.get(:moreBefore) as Boolean) {
            drawOverflowIndicator(
                dc,
                calculateFanAngle(-1, visibleIndicatorCount, angleStep),
                centerX,
                centerY,
                _radius
            );
        }

        var start = currentPageWindow.get(:start) as Number;

        for (var i = 0; i < visibleIndicatorCount; i++) {
            var page = start + i;
            drawPageIndicator(
                dc,
                calculateFanAngle(i, visibleIndicatorCount, angleStep),
                centerX,
                centerY,
                _radius,
                page
            );
        }

        if (currentPageWindow.get(:moreAfter) as Boolean) {
            drawOverflowIndicator(
                dc,
                calculateFanAngle(visibleIndicatorCount, visibleIndicatorCount, angleStep),
                centerX,
                centerY,
                _radius
            );
        }

    }

    private function drawPageIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                       centerY as Number, radius as Float, page as Number) as Void {
        var point = calculatePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        if (page == _currentPage) {
            if (dc has :setAntiAlias) {
                dc.setAntiAlias(true);
            }

            var color = Graphics.createColor(255, ACTIVE_INDICATOR_COLOR_CHANNEL, ACTIVE_INDICATOR_COLOR_CHANNEL, ACTIVE_INDICATOR_COLOR_CHANNEL);
            dc.setColor(color, system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);
            return;
        }

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }

        if (page == _previousPage) {
            var color = Graphics.createColor(255, _inactiveIndicatorColorChannel, _inactiveIndicatorColorChannel, _inactiveIndicatorColorChannel);
            dc.setColor(color, system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);
        }

        dc.setColor(INACTIVE_INDICATOR_STROKE_COLOR, system_color_dark__background.background);
        dc.drawCircle(x, y, _pageIndicatorRadius);
    }

    private function drawOverflowIndicator(dc as Graphics.Dc, angle as Float, centerX as Number,
                                           centerY as Number, radius as Float) as Void {
        var color = Graphics.createColor(255, INACTIVE_INDICATOR_COLOR_CHANNEL, INACTIVE_INDICATOR_COLOR_CHANNEL, INACTIVE_INDICATOR_COLOR_CHANNEL);
        var point = calculatePointOnCircle(angle, centerX, centerY, radius);
        var x = point[0];
        var y = point[1];

        dc.setColor(color, system_color_dark__background.background);
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

        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.clear();
    }

    function isVisible() as Boolean {
        return _state == PAGE_INDICATOR_VISIBLE;
    }

    function showIndicator() as Void {
        _radius = _radiusStart;
        _state = _pageCount < MIN_PAGE_INDICATORS
            ? PAGE_INDICATOR_HIDDEN
            : PAGE_INDICATOR_VISIBLE;

        if (!isVisible()) {
            return;
        }

        WatchUi.cancelAllAnimations();
        _timer.stop();

        WatchUi.requestUpdate();
        _timer.start(method(:onHideStart), VISIBLE_DURATION_MS, false);
    }

    function hideIndicator() as Void {
        _state = PAGE_INDICATOR_HIDDEN;
        clear();
    }

    // A rebuild has no "from" page to cross-fade out of, hence both indices
    // taking the same value. Only showIndicator arms the auto-hide timer, so a
    // count change may hide but must never reveal: anything revealed here would
    // stay on screen indefinitely.
    function setPageCount(pageCount as Number, page as Number) as Void {
        _pageCount = pageCount;
        _currentPage = page;
        _previousPage = page;

        if (isVisible() && _pageCount < MIN_PAGE_INDICATORS) {
            dismiss();
        }
    }

    function updateIndex(index as Number) as Void {
        _previousPage = _currentPage;
        _currentPage = index;

        onIndexUpdate();
        showIndicator();
        draw();
    }

    private function calculateFanAngle(i as Number, visibleIndicatorCount as Number, angleStep as Float) as Float {
        return START_ANGLE - (i - (visibleIndicatorCount - 1) / 2.0) * angleStep;
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
}
