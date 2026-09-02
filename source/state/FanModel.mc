import Toybox.Lang;

class FanModel extends ToggleableModel {
    public var speed as String or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        speed as String or Null) {
        ToggleableModel.initialize(id, state, name, available, areaId, memberIds);
        self.speed = speed;
    }
}
