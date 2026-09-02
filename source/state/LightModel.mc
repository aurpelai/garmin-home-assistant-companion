import Toybox.Lang;

class LightModel extends ToggleableModel {
    public var brightness as String or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        brightness as String or Null) {
        ToggleableModel.initialize(id, state, name, available, areaId, memberIds);
        self.brightness = brightness;
    }
}
