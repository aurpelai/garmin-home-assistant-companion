import Toybox.Lang;
import Toybox.Test;

(:test)
function lookupsDefaultToEmptyBeforeAFetch(logger as Test.Logger) as Boolean {
    var aggregates = new Aggregates();
    var area = aggregates.buildAreaAggregate("area.ghost");

    Test.assert(aggregates.getHomeLightSummary() == null);
    Test.assert(aggregates.buildFloorAggregate("floor.ghost").lightSummary == null);
    Test.assertEqual(area.lightCount.available, 0);
    Test.assertEqual(area.lightCount.on, 0);
    Test.assertEqual(area.averages.size(), 0);
    return true;
}

(:test)
function areaAndFloorMeansDoNotCollideOnAnIdTheyShare(logger as Test.Logger) as Boolean {
    var aggregates = new Aggregates();

    aggregates.setSensors(
        { "shared" => { "temperature" => "18.0 °C" } },
        { "shared" => { "temperature" => "22.0 °C" } },
        { "temperature" => "20.0 °C" });

    Test.assert((aggregates.buildAreaAggregate("shared").averages.get("temperature") as String).equals("18.0 °C"));
    Test.assert((aggregates.buildFloorAggregate("shared").averages.get("temperature") as String).equals("22.0 °C"));
    Test.assert((aggregates.getHomeAverages().get("temperature") as String).equals("20.0 °C"));
    return true;
}

(:test)
function anAreaBundlesItsLightTallyWithItsMeans(logger as Test.Logger) as Boolean {
    var aggregates = new Aggregates();

    aggregates.setLights(
        { "area.room" => new LightCount(2, 3, 1) },
        { "floor.g" => LightSummary.SOME_ON },
        LightSummary.SOME_ON);
    aggregates.setSensors(
        { "area.room" => { "temperature" => "21.0 °C" } },
        {} as Dictionary<String, Dictionary<String, String>>,
        {} as Dictionary<String, String>);

    var area = aggregates.buildAreaAggregate("area.room");
    Test.assertEqual(area.lightCount.on, 2);
    Test.assert((area.averages.get("temperature") as String).equals("21.0 °C"));
    Test.assert((aggregates.buildFloorAggregate("floor.g").lightSummary as String).equals(LightSummary.SOME_ON));
    Test.assert((aggregates.getHomeLightSummary() as String).equals(LightSummary.SOME_ON));
    return true;
}
