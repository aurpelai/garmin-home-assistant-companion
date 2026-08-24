import Toybox.Lang;

class SensorModel {
    public var id as String;
    public var value as Float or Null;
    public var friendlyState as String;
    public var displayPrecision as Number;
    public var unit as String or Null;
    public var deviceClass as String;
    public var name as String;
    public var available as Boolean;
    public var areaId as String or Null;

    function initialize(id as String, value as Float or Null, friendlyState as String,
                        displayPrecision as Number, unit as String or Null,
                        deviceClass as String, name as String,
                        available as Boolean, areaId as String or Null) {
        self.id = id;
        self.value = value;
        self.friendlyState = friendlyState;
        self.displayPrecision = displayPrecision;
        self.unit = unit;
        self.deviceClass = deviceClass;
        self.name = name;
        self.available = available;
        self.areaId = areaId;
    }
}
