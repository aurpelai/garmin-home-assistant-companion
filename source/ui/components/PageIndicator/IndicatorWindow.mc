import Toybox.Lang;

class IndicatorWindow {
    public var start as Number;
    public var count as Number;
    public var hasMoreBefore as Boolean;
    public var hasMoreAfter as Boolean;

    function initialize(start as Number, count as Number, hasMoreBefore as Boolean, hasMoreAfter as Boolean) {
        self.start = start;
        self.count = count;
        self.hasMoreBefore = hasMoreBefore;
        self.hasMoreAfter = hasMoreAfter;
    }
}
