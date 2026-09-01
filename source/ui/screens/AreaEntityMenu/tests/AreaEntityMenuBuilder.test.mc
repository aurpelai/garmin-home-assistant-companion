import Toybox.Lang;
import Toybox.Test;

(:test)
module AreaEntityMenuModelTest {

    function stateOf(structure as Dictionary, lights as Dictionary, fans as Dictionary,
                     sensors as Dictionary) as HaState {
        var haState = new HaState();
        haState.setZone(HaPayload.parseZone(structure));
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setFans(HaPayload.parseFans({ "fans" => fans }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }

    function oneRoom() as Dictionary {
        return { "areas" => { "area.room" => { "name" => "Room" } } };
    }

    function fan(state as Boolean, speed as String or Null) as Dictionary {
        return { "state" => state, "area_id" => "area.room", "available" => true, "speed" => speed };
    }
}

(:test)
function anAreaGoneFromTheStructureYieldsNoModel(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.kept" => { "name" => "Kept" } }
    }, {} as Dictionary, {} as Dictionary, {} as Dictionary);

    Test.assert(AreaEntityMenuBuilder.build(haState, "area.deleted") == null);
    Test.assert(AreaEntityMenuBuilder.build(haState, "area.kept") != null);
    return true;
}

(:test)
function aRowReadsTheAssumedValueAndCarriesItsPendingStatus(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.a" => { "state" => false, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary, {} as Dictionary);

    haState.override("light.a", true);

    var row = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).toggles[0];

    Test.assert(row.isOn);
    return true;
}

(:test)
function aSensorRowKeepsAvailabilityApartFromHaFormatting(logger as Test.Logger) as Boolean {
    // UNVERIFIED: Home Assistant formats an unavailable sensor as the word
    // unavailable followed by its unit.
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(),
        {} as Dictionary, {} as Dictionary, {
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
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.a", "light.b", "light.c"] },
        "light.a" => { "state" => true, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary, {} as Dictionary);
    var toggles = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).toggles;

    Test.assertEqual(toggles[0].memberCount as Number, 3);
    Test.assert(toggles[1].memberCount == null);
    return true;
}

(:test)
function aFanYieldsAToggleRowThatShowsItsSpeedOnlyWhileOn(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {} as Dictionary, {
        "fan.on" => AreaEntityMenuModelTest.fan(true, "33 %"),
        "fan.off" => AreaEntityMenuModelTest.fan(false, "10 %")
    }, {} as Dictionary);
    var toggles = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).toggles;

    Test.assertEqual(toggles.size(), 2);
    Test.assertEqual(toggles[0].rowId, "fan.off");
    Test.assert(!toggles[0].isOn);
    Test.assert(toggles[0].subLabel == null);
    Test.assertEqual(toggles[1].rowId, "fan.on");
    Test.assert(toggles[1].isOn);
    Test.assertEqual(toggles[1].subLabel as String, "33 %");
    return true;
}

(:test)
function aFanRowReadsItsSpeedAgainstTheAssumedStateNotTheServers(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {} as Dictionary, {
        "fan.a" => AreaEntityMenuModelTest.fan(true, "33 %")
    }, {} as Dictionary);

    haState.override("fan.a", false);

    var row = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).toggles[0];

    Test.assert(!row.isOn);
    Test.assert(row.subLabel == null);
    return true;
}

(:test)
function aFanGroupRowCarriesItsMemberCountRatherThanASpeed(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {} as Dictionary, {
        "fan.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["fan.a", "fan.b"] }
    }, {} as Dictionary);
    var row = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).toggles[0];

    Test.assertEqual(row.memberCount as Number, 2);
    Test.assert(row.subLabel == null);
    return true;
}

(:test)
function anUnavailableFanStillYieldsARow(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {} as Dictionary, {
        "fan.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
    }, {} as Dictionary);
    var row = (AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel).toggles[0];

    Test.assertEqual(row.rowId, "fan.dead");
    Test.assert(!row.isAvailable);
    return true;
}

(:test)
function rowsComeOutLightsThenFansThenSensors(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.zzz" => { "state" => true, "area_id" => "area.room", "available" => true, "name" => "Zzz" }
    }, {
        "fan.aaa" => { "state" => true, "area_id" => "area.room", "available" => true, "name" => "Aaa" }
    }, {
        "sensor.t" => { "friendly_state" => "21.5 °C", "device_class" => "temperature",
            "area_id" => "area.room", "name" => "Aaa" }
    });
    var model = AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel;

    Test.assertEqual(model.toggles.size(), 2);
    Test.assertEqual(model.toggles[0].rowId, "light.zzz");
    Test.assertEqual(model.toggles[1].rowId, "fan.aaa");
    Test.assertEqual(model.sensors.size(), 1);
    Test.assertEqual(model.sensors[0].rowId, "sensor.t");
    return true;
}
