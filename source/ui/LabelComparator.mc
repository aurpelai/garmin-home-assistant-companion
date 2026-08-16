import Toybox.Lang;

class LabelComparator {
    private var _labelById as Dictionary<String, String>;

    function initialize(labelById as Dictionary<String, String>) {
        _labelById = labelById;
    }

    function compare(a as Object, b as Object) as Number {
        var byLabel = (_labelById.get(a as String) as String).compareTo(_labelById.get(b as String) as String);
        return byLabel != 0 ? byLabel : (a as String).compareTo(b as String);
    }
}
