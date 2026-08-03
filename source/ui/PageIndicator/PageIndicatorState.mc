import Toybox.Lang;

enum State {
    PAGE_INDICATOR_HIDDEN,
    PAGE_INDICATOR_VISIBLE
}

class PageIndicatorState {
    private var _state as State;

    function initialize() {
        _state = PAGE_INDICATOR_HIDDEN;
    }

    function onTrigger(pageCount as Number) as Void {
        _state = pageCount < 2 ? PAGE_INDICATOR_HIDDEN : PAGE_INDICATOR_VISIBLE;
    }

    function onHidden() as Void {
        _state = PAGE_INDICATOR_HIDDEN;
    }

    function isVisible() as Boolean {
        return _state == PAGE_INDICATOR_VISIBLE;
    }
}
