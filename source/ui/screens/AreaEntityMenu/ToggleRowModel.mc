import Toybox.Lang;

class ToggleRowModel {
    public var id as String;
    public var name as String or Null;
    public var isOn as Boolean;
    public var subLabel as String or Null;

    function initialize(id as String, name as String or Null, isOn as Boolean,
                        subLabel as String or Null) {
        self.id = id;
        self.name = name;
        self.isOn = isOn;
        self.subLabel = subLabel;
    }
}
