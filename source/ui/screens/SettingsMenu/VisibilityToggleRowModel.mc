import Toybox.Lang;

class VisibilityToggleRowModel {
    public var id as String;
    public var name as String;
    public var isFloor as Boolean;
    public var isVisible as Boolean;

    function initialize(id as String, name as String, isFloor as Boolean, isVisible as Boolean) {
        self.id = id;
        self.name = name;
        self.isFloor = isFloor;
        self.isVisible = isVisible;
    }
}
