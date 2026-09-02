import Toybox.Lang;

class ToggleRowModel {
    public var rowId as String;
    public var name as String or Null;
    public var isOn as Boolean;
    public var subLabel as String or Null;

    function initialize(rowId as String, name as String or Null, isOn as Boolean,
                        subLabel as String or Null) {
        self.rowId = rowId;
        self.name = name;
        self.isOn = isOn;
        self.subLabel = subLabel;
    }
}
