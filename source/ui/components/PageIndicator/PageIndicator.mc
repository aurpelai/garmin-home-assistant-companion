import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

enum PageIndicatorState {
    PAGE_INDICATOR_HIDDEN,
    PAGE_INDICATOR_VISIBLE
}

typedef IndicatorLayout as interface {
    function reset() as Void;
    function startDismiss(onHidden as (Method() as Void)) as Void;
    function draw(dc as Graphics.Dc, indicator as PageIndicator, start as Number, count as Number,
                   moreBefore as Boolean, moreAfter as Boolean) as Void;
};

class PageIndicator {
    private const MAX_PAGE_INDICATORS = 5;

    private const SLIDE_OUT_DURATION = 0.2;
    private const VISIBLE_DURATION_MS = 1800;
    private const INDICATOR_FADE_DURATION = 0.05;

    private const PAGE_INDICATOR_INSET = 8;

    private const ACTIVE_INDICATOR_COLOR_CHANNEL = 254; // NOTE: 255 causes Graphics.createColor to return -1 (transparent)
    private const INACTIVE_INDICATOR_COLOR_CHANNEL = 0;
    private const INACTIVE_INDICATOR_STROKE_COLOR = Graphics.COLOR_LT_GRAY;

    private const OVERFLOW_INDICATOR_STROKE_COLOR = Graphics.COLOR_DK_GRAY;

    private var _pageIndicatorRadius as Number;
    private var _pageOverflowRadius as Number;
    public var inactiveIndicatorColorChannel as Number;

    private var _layer as WatchUi.Layer;
    private var _state as PageIndicatorState;
    private var _timer as Timer.Timer;

    private var _radialLayout as RadialLayout;
    private var _axialLayout as AxialLayout;

    // Captured at reveal and frozen for the visible lifetime: a background rebuild
    // must never reshape an indicator that is on screen. Do not recompute in draw.
    private var _layout as IndicatorLayout;
    private var _window as Array;

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
        var spacing = dimensions.get("spacing") as Number;

        var dc = _layer.getDc();
        var centerX = dc != null ? dc.getWidth() / 2 : 0;
        var centerY = dc != null ? dc.getHeight() / 2 : 0;
        var radiusStart = dc != null
            ? (dc.getWidth() / 2 - PAGE_INDICATOR_INSET - _pageIndicatorRadius).toFloat()
            : 0.0;
        var radiusEnd = dc != null
            ? (dc.getWidth() / 2 + PAGE_INDICATOR_INSET + _pageIndicatorRadius).toFloat()
            : 0.0;

        _radialLayout = new RadialLayout(centerX, centerY, radiusStart, radiusEnd, spacing, SLIDE_OUT_DURATION);
        _axialLayout = new AxialLayout(centerX, centerY, radiusStart, radiusEnd, spacing, SLIDE_OUT_DURATION);
        _window = resolveWindow();
        _layout = selectLayout(_window[1] as Number);

        _timer = new Timer.Timer();
        inactiveIndicatorColorChannel = INACTIVE_INDICATOR_COLOR_CHANNEL;
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
        _layout.startDismiss(method(:hideIndicator));
    }

    private function onIndexUpdate() as Void {
        WatchUi.animate(
            self,
            :inactiveIndicatorColorChannel,
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

        clear();

        _layout.draw(dc, self, _window[0] as Number, _window[1] as Number, _window[2] as Boolean, _window[3] as Boolean);
    }

    private function resolveWindow() as Array {
        if (_pageCount <= MAX_PAGE_INDICATORS) {
            return [0, _pageCount, false, false];
        }

        if (_currentPage <= MAX_PAGE_INDICATORS - 1) {
            return [0, MAX_PAGE_INDICATORS, false, true];
        }

        if (_currentPage >= _pageCount - MAX_PAGE_INDICATORS) {
            return [_pageCount - MAX_PAGE_INDICATORS, MAX_PAGE_INDICATORS, true, false];
        }

        return [_currentPage - MAX_PAGE_INDICATORS / 2, MAX_PAGE_INDICATORS, true, true];
    }

    function drawIndicator(dc as Graphics.Dc, x as Float, y as Float, page as Number) as Void {
        if (page == _currentPage) {
            Rendering.useAntiAlias(dc, true);

            var color = Graphics.createColor(255, ACTIVE_INDICATOR_COLOR_CHANNEL, ACTIVE_INDICATOR_COLOR_CHANNEL, ACTIVE_INDICATOR_COLOR_CHANNEL);
            dc.setColor(color, system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);

            return;
        }

        Rendering.useAntiAlias(dc, false);

        if (page == _previousPage) {
            var color = Graphics.createColor(255, inactiveIndicatorColorChannel, inactiveIndicatorColorChannel, inactiveIndicatorColorChannel);
            dc.setColor(color, system_color_dark__background.background);
            dc.fillCircle(x, y, _pageIndicatorRadius);
        }

        dc.setColor(INACTIVE_INDICATOR_STROKE_COLOR, system_color_dark__background.background);
        dc.drawCircle(x, y, _pageIndicatorRadius);
    }

    function drawOverflowIndicator(dc as Graphics.Dc, x as Float, y as Float) as Void {
        Rendering.useAntiAlias(dc, false);

        dc.setColor(OVERFLOW_INDICATOR_STROKE_COLOR, system_color_dark__background.background);
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
        _window = resolveWindow();
        _layout = selectLayout(_window[1] as Number);
        _layout.reset();
        _state = hasMultiplePages()
            ? PAGE_INDICATOR_VISIBLE
            : PAGE_INDICATOR_HIDDEN;

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

        if (isVisible() && !hasMultiplePages()) {
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

    private function hasMultiplePages() as Boolean {
        return _pageCount > 1;
    }

    private function selectLayout(count as Number) as IndicatorLayout {
        return count == 2 ? _axialLayout : _radialLayout;
    }
}
