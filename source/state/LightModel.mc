import Toybox.Lang;

class LightModel extends ToggleableModel {
    public var brightness as Number or Null;
    public var colorTemperatureKelvin as Number or Null;
    public var minColorTemperatureKelvin as Number or Null;
    public var maxColorTemperatureKelvin as Number or Null;
    public var supportsColorTemperature as Boolean;
    public var optimisticBrightness as Number or Null;
    public var optimisticColorTemperatureKelvin as Number or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        brightness as Number or Null, colorTemperatureKelvin as Number or Null,
                        minColorTemperatureKelvin as Number or Null, maxColorTemperatureKelvin as Number or Null,
                        supportsColorTemperature as Boolean) {
        ToggleableModel.initialize(id, state, name, available, areaId, memberIds);
        self.brightness = brightness;
        self.colorTemperatureKelvin = colorTemperatureKelvin;
        self.minColorTemperatureKelvin = minColorTemperatureKelvin;
        self.maxColorTemperatureKelvin = maxColorTemperatureKelvin;
        self.supportsColorTemperature = supportsColorTemperature;
        optimisticBrightness = null;
        optimisticColorTemperatureKelvin = null;
    }

    function resolveBrightness() as Number or Null {
        return optimisticBrightness != null ? optimisticBrightness : brightness;
    }

    function resolveColorTemperatureKelvin() as Number or Null {
        return optimisticColorTemperatureKelvin != null ? optimisticColorTemperatureKelvin : colorTemperatureKelvin;
    }

    function overrideAttribute(field as String, value as Object) as Void {
        if (field.equals("brightness_pct")) {
            optimisticBrightness = value as Number;
        } else if (field.equals("color_temp_kelvin")) {
            optimisticColorTemperatureKelvin = value as Number;
        }
    }
}
