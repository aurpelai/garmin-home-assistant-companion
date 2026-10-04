import Toybox.Lang;

// Interim: an inert grouping caption the grouped labels menu emits before each
// area's rows, until a custom menu with real dividers replaces it.
class HeaderRowModel {
    public var id as String;
    public var name as String;

    function initialize(id as String, name as String) {
        self.id = id;
        self.name = name;
    }
}
