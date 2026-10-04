import Toybox.Lang;
import Toybox.Test;

// Returns strings that encode which resource and arguments they came from, so a
// builder test asserts the resolution without loading Rez.Strings.
(:test)
class FakeSubLabelProvider {
    function getOff() as String {
        return "Off";
    }

    function getOn() as String {
        return "On";
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

    function formatValue(value as Number) as String {
        return "On • " + value + " %";
    }
}

(:test)
module EntityMenuBuilderTest {

    function stateOf(structure as Dictionary, lights as Dictionary, fans as Dictionary,
                     sensors as Dictionary) as HaState {
        var haState = new HaState();
        haState.setZone(HaPayload.parseZone(structure));
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        haState.setToggleables(Domain.LIGHT, HaPayload.parseLights({ "lights" => lights }));
        haState.setToggleables(Domain.FAN, HaPayload.parseFans({ "fans" => fans }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }

    function oneRoom() as Dictionary {
        return { "areas" => { "area.room" => { "name" => "Room" } } };
    }

    function fan(state as Boolean, speed as Number or Null) as Dictionary {
        return { "state" => state, "area_id" => "area.room", "available" => true, "speed" => speed };
    }

    function light(state as Boolean, brightness as Number or Null) as Dictionary {
        return { "state" => state, "area_id" => "area.room", "available" => true, "brightness" => brightness };
    }

    function build(haState as HaState) as EntityMenuModel {
        return EntityMenuBuilder.build("Room", haState.getToggleablesInArea("area.room"),
            haState.getSensorsInArea("area.room"), new FakeSubLabelProvider());
    }

    function toggleAt(model as EntityMenuModel, index as Number) as ToggleRowModel {
        return model.rows[index] as ToggleRowModel;
    }

    function sensorAt(model as EntityMenuModel, index as Number) as SensorRowModel {
        return model.rows[index] as SensorRowModel;
    }
}

(:test)
function aRowReadsTheAssumedValueAndCarriesItsPendingStatus(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {
        "light.a" => { "state" => false, "area_id" => "area.room", "available" => true }
    }, {} as Dictionary, {} as Dictionary);

    haState.overrideState("light.a", true);

    Test.assert(EntityMenuBuilderTest.toggleAt(EntityMenuBuilderTest.build(haState), 0).isOn);
    return true;
}

(:test)
function aFanShowsItsSpeedWhileOnAndOffEvenWhenASpeedLingers(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {} as Dictionary, {
        "fan.on" => EntityMenuBuilderTest.fan(true, 33),
        "fan.off" => EntityMenuBuilderTest.fan(false, 10)
    }, {} as Dictionary);
    var model = EntityMenuBuilderTest.build(haState);

    Test.assertEqual(model.rows.size(), 2);
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).id, "fan.off");
    Test.assert(!EntityMenuBuilderTest.toggleAt(model, 0).isOn);
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).subLabel as String, "Off");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).id, "fan.on");
    Test.assert(EntityMenuBuilderTest.toggleAt(model, 1).isOn);
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).subLabel as String, "On • 33 %");
    return true;
}

(:test)
function anOnRowWithNoValueShowsOn(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {
        "light.a" => EntityMenuBuilderTest.light(true, null)
    }, {
        "fan.a" => EntityMenuBuilderTest.fan(true, null)
    }, {} as Dictionary);
    var model = EntityMenuBuilderTest.build(haState);

    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).subLabel as String, "On");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).subLabel as String, "On");
    return true;
}

(:test)
function aFanRowReadsItsSpeedAgainstTheAssumedStateNotTheServers(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {} as Dictionary, {
        "fan.a" => EntityMenuBuilderTest.fan(true, 33)
    }, {} as Dictionary);

    haState.overrideState("fan.a", false);

    var row = EntityMenuBuilderTest.toggleAt(EntityMenuBuilderTest.build(haState), 0);

    Test.assert(!row.isOn);
    Test.assertEqual(row.subLabel as String, "Off");
    return true;
}

(:test)
function aGroupShowsItsMemberCountInItsOwnDomainNeverAValue(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.a", "light.b", "light.c"], "brightness" => 50 },
        "light.a" => EntityMenuBuilderTest.light(true, 50)
    }, {
        "fan.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["fan.a"], "speed" => 33 }
    }, {} as Dictionary);
    var model = EntityMenuBuilderTest.build(haState);

    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).id, "light.grp");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).subLabel as String, "Group of 3 light");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).subLabel as String, "On • 50 %");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 2).id, "fan.grp");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 2).subLabel as String, "Group of 1 fan");
    return true;
}

(:test)
function anUnavailableRowReadsUnavailableWhateverElseItCarries(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {
        "light.dead_grp" => { "state" => false, "area_id" => "area.room", "available" => false,
            "memberIds" => [] as Array<String> }
    }, {
        "fan.dead" => { "state" => true, "area_id" => "area.room", "available" => false, "speed" => 33 }
    }, {} as Dictionary);
    var model = EntityMenuBuilderTest.build(haState);

    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).id, "light.dead_grp");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).subLabel as String, "Group unavailable");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).id, "fan.dead");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).subLabel as String, "Unavailable");
    return true;
}

(:test)
function aSensorShowsHomeAssistantsValueUnlessItIsUnavailable(logger as Test.Logger) as Boolean {
    // UNVERIFIED: Home Assistant formats an unavailable sensor as the word
    // unavailable followed by its unit.
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(),
        {} as Dictionary, {} as Dictionary, {
        "sensor.dead" => { "friendly_state" => "unavailable °C", "device_class" => "temperature",
            "area_id" => "area.room", "available" => false },
        "sensor.live" => { "friendly_state" => "21.5 °C", "device_class" => "humidity",
            "area_id" => "area.room", "available" => true }
    });
    var model = EntityMenuBuilderTest.build(haState);

    Test.assertEqual(EntityMenuBuilderTest.sensorAt(model, 0).id, "sensor.dead");
    Test.assertEqual(EntityMenuBuilderTest.sensorAt(model, 0).subLabel, "Unavailable");
    Test.assertEqual(EntityMenuBuilderTest.sensorAt(model, 1).id, "sensor.live");
    Test.assertEqual(EntityMenuBuilderTest.sensorAt(model, 1).subLabel, "21.5 °C");
    return true;
}

(:test)
function rowsComeOutLightsThenFansThenSensors(logger as Test.Logger) as Boolean {
    var haState = EntityMenuBuilderTest.stateOf(EntityMenuBuilderTest.oneRoom(), {
        "light.zzz" => { "state" => true, "area_id" => "area.room", "available" => true, "name" => "Zzz" }
    }, {
        "fan.aaa" => { "state" => true, "area_id" => "area.room", "available" => true, "name" => "Aaa" }
    }, {
        "sensor.t" => { "friendly_state" => "21.5 °C", "device_class" => "temperature",
            "area_id" => "area.room", "name" => "Aaa" }
    });
    var model = EntityMenuBuilderTest.build(haState);

    Test.assertEqual(model.rows.size(), 3);
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 0).id, "light.zzz");
    Test.assertEqual(EntityMenuBuilderTest.toggleAt(model, 1).id, "fan.aaa");
    Test.assertEqual(EntityMenuBuilderTest.sensorAt(model, 2).id, "sensor.t");
    return true;
}

