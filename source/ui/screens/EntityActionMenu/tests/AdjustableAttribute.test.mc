import Toybox.Lang;
import Toybox.Test;

(:test)
function resolveServiceUsesTheOffServiceOnlyAtZero(logger as Test.Logger) as Boolean {
    var speed = new AdjustableAttribute("fan.a", Rez.Strings.AttrSpeed, Domain.FAN, "turn_on",
        "set_percentage", "percentage", Rez.Strings.Percent, new LevelRange(0, 100, 10), 0, null);

    Test.assertEqual(speed.resolveService(50), "turn_on");
    Test.assertEqual(speed.resolveService(0), "set_percentage");
    return true;
}

(:test)
function resolveServiceStaysOnTheServiceWhenThereIsNoOffService(logger as Test.Logger) as Boolean {
    var brightness = new AdjustableAttribute("light.a", Rez.Strings.AttrBrightness, Domain.LIGHT,
        "turn_on", null, "brightness_pct", Rez.Strings.Percent, new LevelRange(0, 100, 10), 0, null);

    Test.assertEqual(brightness.resolveService(50), "turn_on");
    Test.assertEqual(brightness.resolveService(0), "turn_on");
    return true;
}
