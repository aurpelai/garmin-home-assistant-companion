import Toybox.Lang;

// The id is required so equal names never order arbitrarily.
typedef Labeled as interface {
    var id as String;
    var name as String;
};

class LabelComparator {

    // UNVERIFIED: toLower is ASCII-only, so non-Latin names order by code point
    // rather than locale collation.
    function compare(first as Object, second as Object) as Number {
        var left = first as Labeled;
        var right = second as Labeled;
        var byName = left.name.toLower().compareTo(right.name.toLower());

        return byName != 0 ? byName : left.id.compareTo(right.id);
    }
}
