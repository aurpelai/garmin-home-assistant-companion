import Toybox.Lang;

class SensorRowModel {
    public var rowId as String;
    public var name as String or Null;
    public var subLabel as String;

    function initialize(rowId as String, name as String or Null, subLabel as String) {
        self.rowId = rowId;
        self.name = name;
        self.subLabel = subLabel;
    }
}
