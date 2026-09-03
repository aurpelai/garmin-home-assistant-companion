import Toybox.Lang;
import Toybox.Test;

(:test)
module AttributeBuilderTest {

    function light(brightness as Number or Null, supportsColorTemp as Boolean,
                   colorTempKelvin as Number or Null) as LightModel {
        return new LightModel("light.a", true, "A", true, "area.a", null,
            brightness, colorTempKelvin, 2500, 5000, supportsColorTemp);
    }

    function fan(speed as Number or Null, supportsSpeed as Boolean,
                 supportsOscillation as Boolean, oscillating as Boolean or Null) as FanModel {
        return new FanModel("fan.a", true, "A", true, "area.a", null,
            speed, oscillating, supportsSpeed, supportsOscillation);
    }
}

(:test)
function aPlainLightOffersOnlyBrightness(logger as Test.Logger) as Boolean {
    var attributes = AttributeBuilder.build(AttributeBuilderTest.light(50, false, null));

    Test.assertEqual(attributes.size(), 1);
    Test.assertEqual(attributes[0].field, "brightness_pct");
    Test.assertEqual(attributes[0].current as Number, 50);
    return true;
}

(:test)
function aColorTempLightAlsoOffersColorOverItsOwnKelvinRange(logger as Test.Logger) as Boolean {
    var attributes = AttributeBuilder.build(AttributeBuilderTest.light(50, true, 3000));

    Test.assertEqual(attributes.size(), 2);
    var color = attributes[1];
    Test.assertEqual(color.field, "color_temp_kelvin");
    Test.assertEqual(color.current as Number, 3000);
    Test.assertEqual((color.range as ValueRange).min, 2500);
    Test.assertEqual((color.range as ValueRange).max, 5000);
    return true;
}

(:test)
function aFanOffersSpeedAndOscillationForWhatItSupports(logger as Test.Logger) as Boolean {
    var attributes = AttributeBuilder.build(AttributeBuilderTest.fan(30, true, true, false));

    Test.assertEqual(attributes.size(), 2);
    Test.assertEqual(attributes[0].field, "percentage");
    Test.assertEqual(attributes[0].current as Number, 30);
    Test.assertEqual(attributes[1].field, "oscillating");
    Test.assert(attributes[1].isToggle());
    Test.assert(!(attributes[1].currentOn as Boolean));
    return true;
}

(:test)
function aFanWithoutSpeedSupportOmitsSpeed(logger as Test.Logger) as Boolean {
    var attributes = AttributeBuilder.build(AttributeBuilderTest.fan(null, false, true, true));

    Test.assertEqual(attributes.size(), 1);
    Test.assertEqual(attributes[0].field, "oscillating");
    return true;
}
