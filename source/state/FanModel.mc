import Toybox.Lang;

class FanModel extends ToggleableModel {
    public var speed as Number or Null;
    public var oscillating as Boolean or Null;
    public var supportsSpeed as Boolean;
    public var supportsOscillation as Boolean;
    public var assumedSpeed as Number or Null;
    public var assumedOscillating as Boolean or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        speed as Number or Null, oscillating as Boolean or Null,
                        supportsSpeed as Boolean, supportsOscillation as Boolean) {
        ToggleableModel.initialize(id, state, name, available, areaId, memberIds);
        self.speed = speed;
        self.oscillating = oscillating;
        self.supportsSpeed = supportsSpeed;
        self.supportsOscillation = supportsOscillation;
        assumedSpeed = null;
        assumedOscillating = null;
    }

    function resolveSpeed() as Number or Null {
        return assumedSpeed != null ? assumedSpeed : speed;
    }

    function resolveOscillation() as Boolean or Null {
        return assumedOscillating != null ? assumedOscillating : oscillating;
    }

    function assume(field as String, value as Object) as Void {
        if (field.equals("percentage")) {
            assumedSpeed = value as Number;
            assumedState = (value as Number) > 0;
        } else if (field.equals("oscillating")) {
            assumedOscillating = value as Boolean;
        }
    }
}
