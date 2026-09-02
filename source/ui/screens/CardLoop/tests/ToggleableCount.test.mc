import Toybox.Lang;
import Toybox.Test;

(:test)
module ToggleableCountTest {

    function light(state as Boolean, available as Boolean) as LightModel {
        return new LightModel("light.x", state, "X", available, "area.a", null, null);
    }

    function group(memberIds as Array<String>) as LightModel {
        return new LightModel("light.group", true, "Group", true, "area.a", memberIds, null);
    }
}

(:test)
function tallyCountsOnAvailableAndUnavailable(logger as Test.Logger) as Boolean {
    var count = ToggleableCount.build([
        ToggleableCountTest.light(true, true),
        ToggleableCountTest.light(false, true),
        ToggleableCountTest.light(false, false)
    ] as Array<ToggleableModel>);

    Test.assertEqual(count.on, 1);
    Test.assertEqual(count.available, 2);
    Test.assertEqual(count.unavailable, 1);
    return true;
}

(:test)
function aGroupWrapperIsSkippedWhileItsMembersCount(logger as Test.Logger) as Boolean {
    var count = ToggleableCount.build([
        ToggleableCountTest.group(["light.one", "light.two"]),
        ToggleableCountTest.light(true, true),
        ToggleableCountTest.light(false, true)
    ] as Array<ToggleableModel>);

    Test.assertEqual(count.available, 2);
    Test.assertEqual(count.on, 1);
    return true;
}

(:test)
function anUnavailableLightLandsInUnavailableNotAvailable(logger as Test.Logger) as Boolean {
    var count = ToggleableCount.build([
        ToggleableCountTest.light(true, false)
    ] as Array<ToggleableModel>);

    Test.assertEqual(count.available, 0);
    Test.assertEqual(count.on, 0);
    Test.assertEqual(count.unavailable, 1);
    return true;
}

(:test)
function anOptimisticallyOnLightCountsAsOn(logger as Test.Logger) as Boolean {
    var light = ToggleableCountTest.light(false, true);
    light.assumed = true;

    var count = ToggleableCount.build([light] as Array<ToggleableModel>);

    Test.assertEqual(count.on, 1);
    return true;
}
