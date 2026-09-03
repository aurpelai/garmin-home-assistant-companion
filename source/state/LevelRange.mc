import Toybox.Lang;

class LevelRange {
    public var min as Number;
    public var max as Number;
    public var step as Number;

    function initialize(min as Number, max as Number, step as Number) {
        self.min = min;
        self.max = max;
        self.step = step;
    }

    function next(value as Number) as Number {
        return atIndex(wrapped(indexBelow(value) + 1));
    }

    function previous(value as Number) as Number {
        return atIndex(wrapped(indexAbove(value) - 1));
    }

    function snap(value as Number) as Number {
        return atIndex(nearestIndex(value));
    }

    private function indexBelow(value as Number) as Number {
        return bounded((value - min) / step);
    }

    private function indexAbove(value as Number) as Number {
        var offset = value - min;
        return bounded((offset + step - 1) / step);
    }

    private function nearestIndex(value as Number) as Number {
        return bounded((value - min + step / 2) / step);
    }

    private function bounded(index as Number) as Number {
        if (index < 0) {
            return 0;
        }
        return index > lastIndex() ? lastIndex() : index;
    }

    private function wrapped(index as Number) as Number {
        var count = lastIndex() + 1;
        return (index + count) % count;
    }

    private function atIndex(index as Number) as Number {
        return min + index * step;
    }

    private function lastIndex() as Number {
        return (max - min) / step;
    }
}
