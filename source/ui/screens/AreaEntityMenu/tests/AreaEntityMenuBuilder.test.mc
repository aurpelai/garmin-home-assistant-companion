import Toybox.Lang;
import Toybox.Test;

// Returns strings that encode which resource and arguments they came from, so a
// builder test asserts the resolution without loading Rez.Strings.
(:test)
class FakeSubLabelProvider {
    function getOff() as String {
        return "Off";
    }

    function getUnavailable() as String {
        return "Unavailable";
    }

    function getGroupUnavailable() as String {
        return "Group unavailable";
    }

    function resolveGroupLabel(domain as String, memberCount as Number) as String {
        return "Group of " + memberCount + " " + domain;
    }
}

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

    function light(state as Boolean, brightness as String or Null) as Dictionary {
        return { "state" => state, "area_id" => "area.room", "available" => true, "brightness" => brightness };
    }

    function build(haState as HaState) as AreaEntityMenuModel {
        return AreaEntityMenuBuilder.build(haState, "area.room", new FakeSubLabelProvider()) as AreaEntityMenuModel;
    }
}

(:test)
function anAreaGoneFromTheStructureYieldsNoModel(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf({
        "areas" => { "area.kept" => { "name" => "Kept" } }
    }, {} as Dictionary, {} as Dictionary, {} as Dictionary);
    var provider = new FakeSubLabelProvider();

    Test.assert(AreaEntityMenuBuilder.build(haState, "area.deleted", provider) == null);
    Test.assert(AreaEntityMenuBuilder.build(haState, "area.kept", provider) != null);
    return true;
}

(:test)
function aRowReadsTheAssumedValueAndCarriesItsPendingStatus(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.a" => { "state" => false, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary, {} as Dictionary);

    haState.override("light.a", true);

    Test.assert(AreaEntityMenuModelTest.build(haState).toggles[0].isOn);
    return true;
}

(:test)
function aFanShowsItsSpeedWhileOnAndOffEvenWhenASpeedLingers(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {} as Dictionary, {
        "fan.on" => AreaEntityMenuModelTest.fan(true, "33 %"),
        "fan.off" => AreaEntityMenuModelTest.fan(false, "10 %")
    }, {} as Dictionary);
    var toggles = AreaEntityMenuModelTest.build(haState).toggles;

    Test.assertEqual(toggles.size(), 2);
    Test.assertEqual(toggles[0].rowId, "fan.off");
    Test.assert(!toggles[0].isOn);
    Test.assertEqual(toggles[0].subLabel as String, "Off");
    Test.assertEqual(toggles[1].rowId, "fan.on");
    Test.assert(toggles[1].isOn);
    Test.assertEqual(toggles[1].subLabel as String, "33 %");
    return true;
}

(:test)
function anOnRowWithNoValueShowsNoSublabel(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.a" => AreaEntityMenuModelTest.light(true, null)
    }, {
        "fan.a" => AreaEntityMenuModelTest.fan(true, null)
    }, {} as Dictionary);
    var toggles = AreaEntityMenuModelTest.build(haState).toggles;

    Test.assert(toggles[0].subLabel == null);
    Test.assert(toggles[1].subLabel == null);
    return true;
}

(:test)
function aFanRowReadsItsSpeedAgainstTheAssumedStateNotTheServers(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {} as Dictionary, {
        "fan.a" => AreaEntityMenuModelTest.fan(true, "33 %")
    }, {} as Dictionary);

    haState.override("fan.a", false);

    var row = AreaEntityMenuModelTest.build(haState).toggles[0];

    Test.assert(!row.isOn);
    Test.assertEqual(row.subLabel as String, "Off");
    return true;
}

(:test)
function aGroupShowsItsMemberCountInItsOwnDomainNeverAValue(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.a", "light.b", "light.c"], "brightness" => "50 %" },
        "light.a" => AreaEntityMenuModelTest.light(true, "50 %")
    }, {
        "fan.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["fan.a"], "speed" => "33 %" }
    }, {} as Dictionary);
    var toggles = AreaEntityMenuModelTest.build(haState).toggles;

    Test.assertEqual(toggles[0].rowId, "light.grp");
    Test.assertEqual(toggles[0].subLabel as String, "Group of 3 light");
    Test.assertEqual(toggles[1].subLabel as String, "50 %");
    Test.assertEqual(toggles[2].rowId, "fan.grp");
    Test.assertEqual(toggles[2].subLabel as String, "Group of 1 fan");
    return true;
}

(:test)
function anUnavailableRowReadsUnavailableWhateverElseItCarries(logger as Test.Logger) as Boolean {
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(), {
        "light.dead_grp" => { "state" => false, "area_id" => "area.room", "available" => false,
            "memberIds" => [] as Array<String> }
    }, {
        "fan.dead" => { "state" => true, "area_id" => "area.room", "available" => false, "speed" => "33 %" }
    }, {} as Dictionary);
    var toggles = AreaEntityMenuModelTest.build(haState).toggles;

    Test.assertEqual(toggles[0].rowId, "light.dead_grp");
    Test.assertEqual(toggles[0].subLabel as String, "Group unavailable");
    Test.assertEqual(toggles[1].rowId, "fan.dead");
    Test.assertEqual(toggles[1].subLabel as String, "Unavailable");
    return true;
}

(:test)
function aSensorShowsHomeAssistantsValueUnlessItIsUnavailable(logger as Test.Logger) as Boolean {
    // UNVERIFIED: Home Assistant formats an unavailable sensor as the word
    // unavailable followed by its unit.
    var haState = AreaEntityMenuModelTest.stateOf(AreaEntityMenuModelTest.oneRoom(),
        {} as Dictionary, {} as Dictionary, {
        "sensor.dead" => { "friendly_state" => "unavailable °C", "device_class" => "temperature",
            "area_id" => "area.room", "available" => false },
        "sensor.live" => { "friendly_state" => "21.5 °C", "device_class" => "humidity",
            "area_id" => "area.room", "available" => true }
    });
    var sensors = AreaEntityMenuModelTest.build(haState).sensors;

    Test.assertEqual(sensors[0].rowId, "sensor.dead");
    Test.assertEqual(sensors[0].subLabel, "Unavailable");
    Test.assertEqual(sensors[1].rowId, "sensor.live");
    Test.assertEqual(sensors[1].subLabel, "21.5 °C");
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
    var model = AreaEntityMenuModelTest.build(haState);

    Test.assertEqual(model.toggles.size(), 2);
    Test.assertEqual(model.toggles[0].rowId, "light.zzz");
    Test.assertEqual(model.toggles[1].rowId, "fan.aaa");
    Test.assertEqual(model.sensors.size(), 1);
    Test.assertEqual(model.sensors[0].rowId, "sensor.t");
    return true;
}
