import Toybox.Lang;
import Toybox.Test;

(:test)
module AssumedAttributeTest {

    function light() as LightModel {
        return new LightModel("light.a", true, "A", true, "area.a", null, 20, 3000, 2000, 6500, true);
    }

    function fan() as FanModel {
        return new FanModel("fan.a", true, "A", true, "area.a", null, 20, false, true, true);
    }
}

(:test)
function assumingBrightnessOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var light = AssumedAttributeTest.light();

    light.assume("brightness_pct", 70);

    Test.assertEqual(light.resolveBrightness() as Number, 70);
    Test.assertEqual(light.brightness as Number, 20);
    return true;
}

(:test)
function assumingColorTempOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var light = AssumedAttributeTest.light();

    light.assume("color_temp_kelvin", 4500);

    Test.assertEqual(light.resolveColorTempKelvin() as Number, 4500);
    return true;
}

(:test)
function assumingSpeedOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var fan = AssumedAttributeTest.fan();

    fan.assume("percentage", 80);

    Test.assertEqual(fan.resolveSpeed() as Number, 80);
    return true;
}

(:test)
function assumingOscillationOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var fan = AssumedAttributeTest.fan();

    fan.assume("oscillating", true);

    Test.assert(fan.resolveOscillation() == true);
    return true;
}
