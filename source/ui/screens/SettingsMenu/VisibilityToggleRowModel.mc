import Toybox.Lang;

class VisibilityToggleRowModel {
    public var id as String;
    public var name as String;
    public var subLabel as String or Null;
    public var isFloor as Boolean;
    public var isVisible as Boolean;

    function initialize(id as String, name as String, subLabel as String or Null, isFloor as Boolean,
                        isVisible as Boolean) {
        self.id = id;
        self.name = name;
        self.subLabel = subLabel;
        self.isFloor = isFloor;
        self.isVisible = isVisible;
    }
}
