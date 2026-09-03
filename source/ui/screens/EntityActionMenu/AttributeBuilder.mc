import Toybox.Lang;

module AttributeBuilder {
    const PERCENT_STEP = 10;
    const KELVIN_STEP = 250;
    const KELVIN_FALLBACK_MIN = 2000;
    const KELVIN_FALLBACK_MAX = 6500;

    function build(toggleable as ToggleableModel) as Array<AdjustableAttribute> {
        if (toggleable instanceof LightModel) {
            return buildLightAttributes(toggleable);
        }
        if (toggleable instanceof FanModel) {
            return buildFanAttributes(toggleable);
        }
        return [] as Array<AdjustableAttribute>;
    }

    function buildLightAttributes(light as LightModel) as Array<AdjustableAttribute> {
        var attributes = [
            new AdjustableAttribute(light.id, Rez.Strings.AttrBrightness, Domain.LIGHT, "turn_on", null,
                "brightness_pct", Rez.Strings.Percent, new ValueRange(0, 100, PERCENT_STEP),
                light.resolveBrightness(), null)
        ] as Array<AdjustableAttribute>;

        if (light.supportsColorTemp) {
            var min = light.minColorTempKelvin;
            var max = light.maxColorTempKelvin;
            var range = new ValueRange(
                min == null ? KELVIN_FALLBACK_MIN : min, max == null ? KELVIN_FALLBACK_MAX : max, KELVIN_STEP);
            attributes.add(new AdjustableAttribute(light.id, Rez.Strings.AttrColorTemp, Domain.LIGHT,
                "turn_on", null, "color_temp_kelvin", Rez.Strings.Kelvin, range,
                light.resolveColorTempKelvin(), null));
        }

        return attributes;
    }

    function buildFanAttributes(fan as FanModel) as Array<AdjustableAttribute> {
        var attributes = [] as Array<AdjustableAttribute>;

        if (fan.supportsSpeed) {
            attributes.add(new AdjustableAttribute(fan.id, Rez.Strings.AttrSpeed, Domain.FAN,
                "turn_on", "set_percentage", "percentage", Rez.Strings.Percent,
                new ValueRange(0, 100, PERCENT_STEP), fan.resolveSpeed(), null));
        }

        if (fan.supportsOscillation) {
            attributes.add(new AdjustableAttribute(fan.id, Rez.Strings.AttrOscillation, Domain.FAN,
                "oscillate", null, "oscillating", null, null, null, fan.resolveOscillation()));
        }

        return attributes;
    }
}
