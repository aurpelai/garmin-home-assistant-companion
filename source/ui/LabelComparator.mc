import Toybox.Lang;

// The id is required so equal names never order arbitrarily.
typedef Labelled as interface {
    var id as String;
    var name as String;
};

class LabelComparator {

    // toLower is ASCII-only, so non-Latin names order by code point rather than
    // locale collation.
    function compare(first as Object, second as Object) as Number {
        var left = first as Labelled;
        var right = second as Labelled;
        var byName = left.name.toLower().compareTo(right.name.toLower());

        return byName != 0 ? byName : left.id.compareTo(right.id);
    }
}
