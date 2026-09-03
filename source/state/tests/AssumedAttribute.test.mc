import Toybox.Lang;
import Toybox.Test;

(:test)
function aLightAssumesBrightnessAndColorTempOverItsServerValues(logger as Test.Logger) as Boolean {
    var light = new LightModel("light.a", true, "A", true, "area.a", null, 20, 3000, 2000, 6500, true);

    light.assumeAttribute("brightness_pct", 70);
    light.assumeAttribute("color_temp_kelvin", 4500);

    Test.assertEqual(light.resolveBrightness() as Number, 70);
    Test.assertEqual(light.resolveColorTempKelvin() as Number, 4500);
    Test.assertEqual(light.brightness as Number, 20);
    return true;
}

(:test)
function aFanAssumesSpeedAndOscillationAndMovesOnOffWithTheSpeed(logger as Test.Logger) as Boolean {
    var fan = new FanModel("fan.a", false, "A", true, "area.a", null, 0, false, true, true);

    fan.assumeAttribute("percentage", 40);
    Test.assertEqual(fan.resolveSpeed() as Number, 40);
    Test.assert(fan.isOn());

    fan.assumeAttribute("oscillating", true);
    Test.assert(fan.resolveOscillation() == true);

    fan.assumeAttribute("percentage", 0);
    Test.assert(!fan.isOn());
    return true;
}
