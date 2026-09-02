import Toybox.Lang;
import Toybox.Test;

(:test)
function lookupsDefaultToEmptyBeforeAFetch(logger as Test.Logger) as Boolean {
    var averages = new SensorAverages();

    Test.assertEqual(averages.getArea("area.ghost").size(), 0);
    Test.assertEqual(averages.getFloor("floor.ghost").size(), 0);
    return true;
}

(:test)
function areaAndFloorMeansDoNotCollideOnAnIdTheyShare(logger as Test.Logger) as Boolean {
    var averages = new SensorAverages();

    averages.set(
        { "shared" => { "temperature" => "18.0 °C" } },
        { "shared" => { "temperature" => "22.0 °C" } });

    Test.assert((averages.getArea("shared").get("temperature") as String).equals("18.0 °C"));
    Test.assert((averages.getFloor("shared").get("temperature") as String).equals("22.0 °C"));
    return true;
}
