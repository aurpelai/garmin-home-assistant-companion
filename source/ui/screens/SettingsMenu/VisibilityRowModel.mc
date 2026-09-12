import Toybox.Lang;

class VisibilityRowModel {
    public var id as String;
    public var name as String;
    public var isVisible as Boolean;

    function initialize(id as String, name as String, isVisible as Boolean) {
        self.id = id;
        self.name = name;
        self.isVisible = isVisible;
    }
}
