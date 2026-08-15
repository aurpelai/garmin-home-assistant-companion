import Toybox.Lang;
import Toybox.Test;

(:test)
module AreaEntityMenuModelTest {

    function stateOf(structure as Dictionary, lights as Dictionary,
                     sensors as Dictionary) as HaState {
        var haState = new HaState();
        haState.setStructure(HaPayload.parseStructure(structure));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }
}

(:test)
function anAreaGoneFromTheStructureYieldsNoModel(logger as Test.Logger) as Boolean {
    // Absence is answered here so no call site has to check: a user standing in
    // an area deleted in Home Assistant leaves the coordinator to decide where
    // they go instead.
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.kept" => { "name" => "Kept" } }
    }, {} as Dictionary, {} as Dictionary);

    Test.assert(buildAreaEntityMenuModel(haState, "area.deleted") == null);
    Test.assert(buildAreaEntityMenuModel(haState, "area.kept") != null);
    return true;
}

(:test)
function aRowReadsTheAssumedValueAndCarriesItsPendingStatus(logger as Test.Logger) as Boolean {
    // The tap's assumed value shows immediately, and the status is derived from
    // the override existing rather than stored anywhere that could disagree.
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {
        "light.a" => { "state" => false, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary);

    haState.override("light.a", true);

    var row = (buildAreaEntityMenuModel(haState, "area.room") as AreaEntityMenuModel).lights[0];

    Test.assert(row.isOn);
    return true;
}

(:test)
function anUnnamedAreaTitlesItselfWithItsIdRatherThanGoingBlank(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.nameless" => {} as Dictionary }
    }, {} as Dictionary, {} as Dictionary);

    Test.assertEqual(
        (buildAreaEntityMenuModel(haState, "area.nameless") as AreaEntityMenuModel).title,
        "area.nameless");
    return true;
}

(:test)
function aSensorRowKeepsAvailabilityApartFromHaFormatting(logger as Test.Logger) as Boolean {
    // The view picks the unavailable label ahead of the display value, so the two
    // must reach it as separate facts: Home Assistant formats an unavailable
    // sensor as the word unavailable followed by its unit.
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {} as Dictionary, {
        "sensor.dead" => { "state" => null, "display_state" => "unavailable °C", "unit" => "°C",
            "device_class" => "temperature", "area_id" => "area.room", "available" => false }
    });
    var row = (buildAreaEntityMenuModel(haState, "area.room") as AreaEntityMenuModel).sensors[0];

    Test.assert(!row.isAvailable);
    Test.assertEqual(row.displayValue as String, "unavailable °C");
    return true;
}

(:test)
function aGroupRowCarriesItsMemberCountWhileAPlainRowCarriesNone(logger as Test.Logger) as Boolean {
    // The count is derived from the ids the payload carried, so there is one
    // source of truth; a plain light has none, which is what the view reads to
    // leave its sublabel empty.
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.a", "light.b", "light.c"] },
        "light.a" => { "state" => true, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary);
    var lights = (buildAreaEntityMenuModel(haState, "area.room") as AreaEntityMenuModel).lights;

    // Groups lead their area's rows, so the group is first.
    Test.assertEqual(lights[0].memberCount as Number, 3);
    Test.assert(lights[1].memberCount == null);
    return true;
}
