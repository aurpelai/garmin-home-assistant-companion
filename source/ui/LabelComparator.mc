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
        var firstLabeled = first as Labeled;
        var secondLabeled = second as Labeled;
        var nameOrder = firstLabeled.name.toLower().compareTo(secondLabeled.name.toLower());

        return nameOrder != 0 ? nameOrder : firstLabeled.id.compareTo(secondLabeled.id);
    }
}
