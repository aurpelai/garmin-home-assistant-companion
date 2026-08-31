import Toybox.Lang;
import Toybox.Test;

(:test)
module AreaEntityMenuModelTest {

    function stateOf(structure as Dictionary, lights as Dictionary,
                     sensors as Dictionary) as HaState {
        var haState = new HaState();
        haState.setZone(HaPayload.parseZone(structure));
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }
}

(:test)
function anAreaGoneFromTheStructureYieldsNoModel(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.kept" => { "name" => "Kept" } }
    }, {} as Dictionary, {} as Dictionary);

    Test.assert(AreaEntityMenuBuilder.build(haState, "area.deleted") == null);
    Test.assert(AreaEntityMenuBuilder.build(haState, "area.kept") != null);
    return true;
}

(:test)
function aRowReadsTheAssumedValueAndCarriesItsPendingStatus(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {
        "light.a" => { "state" => false, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary);

    haState.override("light.a", true);

    var row = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).lights[0];

    Test.assert(row.isOn);
    return true;
}

(:test)
function aSensorRowKeepsAvailabilityApartFromHaFormatting(logger as Test.Logger) as Boolean {
    // UNVERIFIED: Home Assistant formats an unavailable sensor as the word
    // unavailable followed by its unit.
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {} as Dictionary, {
        "sensor.dead" => { "state" => null, "friendly_state" => "unavailable °C", "unit" => "°C",
            "device_class" => "temperature", "area_id" => "area.room", "available" => false }
    });
    var row = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).sensors[0];

    Test.assert(!row.isAvailable);
    Test.assertEqual(row.friendlyState as String, "unavailable °C");
    return true;
}

(:test)
function aGroupRowCarriesItsMemberCountWhileAPlainRowCarriesNone(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.a", "light.b", "light.c"] },
        "light.a" => { "state" => true, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary);
    var lights = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).lights;

    Test.assertEqual(lights[0].memberCount as Number, 3);
    Test.assert(lights[1].memberCount == null);
    return true;
}
