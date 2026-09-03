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

    light.assumeAttribute("brightness_pct", 70);

    Test.assertEqual(light.resolveBrightness() as Number, 70);
    Test.assertEqual(light.brightness as Number, 20);
    return true;
}

(:test)
function assumingColorTempOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var light = AssumedAttributeTest.light();

    light.assumeAttribute("color_temp_kelvin", 4500);

    Test.assertEqual(light.resolveColorTempKelvin() as Number, 4500);
    return true;
}

(:test)
function assumingSpeedOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var fan = AssumedAttributeTest.fan();

    fan.assumeAttribute("percentage", 80);

    Test.assertEqual(fan.resolveSpeed() as Number, 80);
    return true;
}

(:test)
function assumingAPositiveSpeedTurnsTheFanOnAndZeroTurnsItOff(logger as Test.Logger) as Boolean {
    var fan = new FanModel("fan.a", false, "A", true, "area.a", null, 0, false, true, true);

    fan.assumeAttribute("percentage", 40);
    Test.assert(fan.isOn());

    fan.assumeAttribute("percentage", 0);
    Test.assert(!fan.isOn());
    return true;
}

(:test)
function assumingOscillationOverridesTheServerValue(logger as Test.Logger) as Boolean {
    var fan = AssumedAttributeTest.fan();

    fan.assumeAttribute("oscillating", true);

    Test.assert(fan.resolveOscillation() == true);
    return true;
}
