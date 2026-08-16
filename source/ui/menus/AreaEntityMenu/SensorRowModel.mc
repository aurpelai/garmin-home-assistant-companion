import Toybox.Lang;

class SensorRowModel {
    public var rowId as String;
    public var name as String or Null;
    public var displayValue as String or Null;
    public var isAvailable as Boolean;

    function initialize(rowId as String, name as String or Null, displayValue as String or Null,
                        isAvailable as Boolean) {
        self.rowId = rowId;
        self.name = name;
        self.displayValue = displayValue;
        self.isAvailable = isAvailable;
    }
}
