import Toybox.Lang;

class FanModel extends ToggleableModel {
    public var speed as Number or Null;
    public var oscillating as Boolean or Null;
    public var supportsSpeed as Boolean;
    public var supportsOscillation as Boolean;
    public var optimisticSpeed as Number or Null;
    public var optimisticOscillating as Boolean or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        speed as Number or Null, oscillating as Boolean or Null,
                        supportsSpeed as Boolean, supportsOscillation as Boolean) {
        ToggleableModel.initialize(id, state, name, available, areaId, memberIds);
        self.speed = speed;
        self.oscillating = oscillating;
        self.supportsSpeed = supportsSpeed;
        self.supportsOscillation = supportsOscillation;
        optimisticSpeed = null;
        optimisticOscillating = null;
    }

    function resolveSpeed() as Number or Null {
        return optimisticSpeed != null ? optimisticSpeed : speed;
    }

    function resolveOscillation() as Boolean or Null {
        return optimisticOscillating != null ? optimisticOscillating : oscillating;
    }

    function overrideAttribute(field as String, value as Object) as Void {
        if (field.equals("percentage")) {
            optimisticSpeed = value as Number;
            // A running fan is on and a stopped one is off, so a speed change
            // moves the on/off state with it.
            optimisticState = (value as Number) > 0;
        } else if (field.equals("oscillating")) {
            optimisticOscillating = value as Boolean;
        }
    }
}
