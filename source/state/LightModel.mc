import Toybox.Lang;

class LightModel extends ToggleableModel {
    public var brightness as Number or Null;
    public var colorTempKelvin as Number or Null;
    public var minColorTempKelvin as Number or Null;
    public var maxColorTempKelvin as Number or Null;
    public var supportsColorTemp as Boolean;
    public var assumedBrightness as Number or Null;
    public var assumedColorTempKelvin as Number or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null,
                        brightness as Number or Null, colorTempKelvin as Number or Null,
                        minColorTempKelvin as Number or Null, maxColorTempKelvin as Number or Null,
                        supportsColorTemp as Boolean) {
        ToggleableModel.initialize(id, state, name, available, areaId, memberIds);
        self.brightness = brightness;
        self.colorTempKelvin = colorTempKelvin;
        self.minColorTempKelvin = minColorTempKelvin;
        self.maxColorTempKelvin = maxColorTempKelvin;
        self.supportsColorTemp = supportsColorTemp;
        assumedBrightness = null;
        assumedColorTempKelvin = null;
    }

    function resolveBrightness() as Number or Null {
        return assumedBrightness != null ? assumedBrightness : brightness;
    }

    function resolveColorTempKelvin() as Number or Null {
        return assumedColorTempKelvin != null ? assumedColorTempKelvin : colorTempKelvin;
    }

    function assume(field as String, value as Object) as Void {
        if (field.equals("brightness_pct")) {
            assumedBrightness = value as Number;
        } else if (field.equals("color_temp_kelvin")) {
            assumedColorTempKelvin = value as Number;
        }
    }
}
