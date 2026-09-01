import Toybox.Lang;

class LightModel {
    public var id as String;
    public var state as Boolean;
    public var name as String;
    public var available as Boolean;
    public var areaId as String or Null;
    public var memberIds as Array<String> or Null;
    public var assumed as Boolean or Null;
    public var brightness as String or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        brightness as String or Null) {
        self.id = id;
        self.state = state;
        self.name = name;
        self.available = available;
        self.areaId = areaId;
        self.memberIds = memberIds;
        self.brightness = brightness;
        assumed = null;
    }

    function isOn() as Boolean {
        return assumed != null ? assumed : state;
    }

    function isPending() as Boolean {
        return assumed != null;
    }
}
