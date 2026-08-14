import Toybox.Lang;

// One sensor row's facts. Availability stays a separate field rather than being
// folded into the display value: the view picks the unavailable label ahead of
// Home Assistant's formatting, which would otherwise read as the word
// unavailable followed by a unit.
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
