import Toybox.Lang;
import Toybox.Test;

(:test)
function theOffServiceIsSelectedOnlyAtZero(logger as Test.Logger) as Boolean {
    var speed = new AdjustableAttribute("fan.a", Rez.Strings.AttrSpeed, Domain.FAN, "turn_on",
        "set_percentage", "percentage", Rez.Strings.Percent, new ValueRange(0, 100, 10), 0, null);

    Test.assertEqual(speed.selectService(50), "turn_on");
    Test.assertEqual(speed.selectService(0), "set_percentage");
    return true;
}

(:test)
function theServiceIsSelectedWhenThereIsNoOffService(logger as Test.Logger) as Boolean {
    var brightness = new AdjustableAttribute("light.a", Rez.Strings.AttrBrightness, Domain.LIGHT,
        "turn_on", null, "brightness_pct", Rez.Strings.Percent, new ValueRange(0, 100, 10), 0, null);

    Test.assertEqual(brightness.selectService(50), "turn_on");
    Test.assertEqual(brightness.selectService(0), "turn_on");
    return true;
}
