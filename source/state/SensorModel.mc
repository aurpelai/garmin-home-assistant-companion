import Toybox.Lang;

class SensorModel {
    public var id as String;
    public var friendlyState as String;
    public var deviceClass as String;
    public var name as String;
    public var available as Boolean;
    public var areaId as String or Null;

    function initialize(id as String, friendlyState as String, deviceClass as String,
                        name as String, available as Boolean, areaId as String or Null) {
        self.id = id;
        self.friendlyState = friendlyState;
        self.deviceClass = deviceClass;
        self.name = name;
        self.available = available;
        self.areaId = areaId;
    }
}
