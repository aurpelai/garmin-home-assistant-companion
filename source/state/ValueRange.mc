import Toybox.Lang;

// Steps land on round multiples of the step (…, 2500, 2750, …), with min and max
// as the extreme stops — so the first step off min and the last onto max may be
// shorter than a full step. Only stepping moves the value onto the grid; an
// unstepped value stays exactly as it was.
class ValueRange {
    public var min as Number;
    public var max as Number;
    public var step as Number;

    function initialize(min as Number, max as Number, step as Number) {
        self.min = min;
        self.max = max;
        self.step = step;
    }

    function next(value as Number) as Number {
        if (value >= max) {
            return max;
        }
        var above = (value / step + 1) * step;
        return above >= max ? max : above;
    }

    function previous(value as Number) as Number {
        if (value <= min) {
            return min;
        }
        var below = (value - 1) / step * step;
        return below <= min ? min : below;
    }
}
