import Toybox.Lang;

class SensorModel {
    // Null when the sensor's state was non-numeric; never degraded to a zero.
    public var value as Float or Null;
    // Home Assistant's own formatting, never reparsed.
    public var displayValue as String or Null;
    public var unit as String or Null;
    public var deviceClass as String or Null;
    public var name as String or Null;
    public var available as Boolean;
    public var areaId as String or Null;

    function initialize(value as Float or Null, displayValue as String or Null, unit as String or Null,
                        deviceClass as String or Null, name as String or Null, available as Boolean,
                        areaId as String or Null) {
        self.value = value;
        self.displayValue = displayValue;
        self.unit = unit;
        self.deviceClass = deviceClass;
        self.name = name;
        self.available = available;
        self.areaId = areaId;
    }
}
