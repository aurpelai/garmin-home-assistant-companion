import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure parsing/derivation logic in HomeState.
// Run: monkeyc --unit-test ... then `monkeydo bin/test.prg venu3 -t`.

(:test)
function parsesTemplateData(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen",
                "lights" => ["light.kitchen_ceiling", "light.kitchen_counter"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.bedroom"] }
        },
        "lights" => {
            "light.kitchen_ceiling" => { "state" => false, "name" => "Ceiling", "available" => true },
            "light.kitchen_counter" => { "state" => false, "name" => "Counter", "available" => true },
            "light.bedroom" => { "state" => false, "name" => "Bedroom", "available" => true }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 2);
    Test.assertEqual((state.areas.get("area.bedroom") as Dictionary).get(:name) as String, "Bedroom");
    Test.assertEqual((state.areas.get("area.kitchen") as Dictionary).get(:name) as String, "Kitchen");
    Test.assertEqual((state.listLightsInArea("area.kitchen")).size(), 2);
    return true;
}

(:test)
function isEmptyWhenNoAreaHasEntities(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.empty" => { "name" => "Empty", "lights" => [] as Array<String> } } };
    Test.assert(HomeState.fromTemplateData(data).isEmpty());
    Test.assert(!HomeState.fromTemplateData({
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } }
    }).isEmpty());
    return true;
}

(:test)
function isGroupReflectsMemberCountPresence(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.grp", "light.plain"] } },
        "lights" => {
            "light.grp" => { "state" => false, "memberCount" => 3 },
            "light.plain" => { "state" => false }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isGroup("light.grp"));
    Test.assert(!state.isGroup("light.plain"));
    Test.assert(!state.isGroup("light.unknown"));
    return true;
}

(:test)
function memberCountReflectsPayloadValue(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.grp"] } },
        "lights" => { "light.grp" => { "state" => false, "memberCount" => 4 } }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getMemberCount("light.grp"), 4);
    return true;
}

(:test)
function dropsInvalidMemberCounts(logger as Test.Logger) as Boolean {
    // The crash-guard case: a memberCount that is not a valid non-negative
    // integer (string / array / negative) drops the group signal entirely, so
    // the entity is not a group — it renders as a plain row rather than flowing
    // a bad value into the sublabel and crashing the menu.
    var data = {
        "areas" => { "area.a" => { "name" => "A",
            "lights" => ["light.strc", "light.arrc", "light.negc", "light.ok"] } },
        "lights" => {
            "light.strc" => { "state" => false, "memberCount" => "3" },
            "light.arrc" => { "state" => false, "memberCount" => ["light.a"] },
            "light.negc" => { "state" => false, "memberCount" => -1 },
            "light.ok" => { "state" => false, "memberCount" => 2 }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.strc"));
    Test.assert(!state.isGroup("light.arrc"));
    Test.assert(!state.isGroup("light.negc"));
    // The one valid entry survives.
    Test.assert(state.isGroup("light.ok"));
    Test.assertEqual(state.getMemberCount("light.ok"), 2);
    return true;
}

(:test)
function ordersGroupsFirstDespiteName(logger as Test.Logger) as Boolean {
    // "light.zzz_group" sorts AFTER the plain lights alphabetically but must
    // still come first because it is a group.
    var data = {
        "areas" => { "area.a" => { "name" => "A",
            "lights" => ["light.apple", "light.zzz_group", "light.mango"] } },
        "lights" => { "light.zzz_group" => { "state" => false, "memberCount" => 2 } }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights.size(), 3);
    Test.assertEqual(lights[0], "light.zzz_group");   // group first
    Test.assertEqual(lights[1], "light.apple");       // then plain, alphabetical
    Test.assertEqual(lights[2], "light.mango");
    return true;
}

(:test)
function listLightsInAreaOrdersGroupsFirst(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.living" => { "name" => "Living",
            "lights" => ["light.lamp", "light.b_group", "light.a_group", "light.ceiling"] } },
        "lights" => {
            "light.a_group" => { "state" => false, "memberCount" => 1 },
            "light.b_group" => { "state" => false, "memberCount" => 4 }
        }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.living");
    Test.assertEqual(lights.size(), 4);
    // Groups first, alphabetical among themselves.
    Test.assertEqual(lights[0], "light.a_group");
    Test.assertEqual(lights[1], "light.b_group");
    // Then plain lights, alphabetical among themselves.
    Test.assertEqual(lights[2], "light.ceiling");
    Test.assertEqual(lights[3], "light.lamp");
    return true;
}

(:test)
function ordersByNameNotId(logger as Test.Logger) as Boolean {
    // The whole point of names: order by the visible name, not the entity id.
    // light.zzz has name "Aaa" and must sort FIRST despite its id sorting last.
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.aaa", "light.zzz"] } },
        "lights" => {
            "light.aaa" => { "state" => false, "name" => "Zebra" },
            "light.zzz" => { "state" => false, "name" => "Aaa" }
        }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights.size(), 2);
    Test.assertEqual(lights[0], "light.zzz");   // name "Aaa" first
    Test.assertEqual(lights[1], "light.aaa");   // name "Zebra" second
    return true;
}

(:test)
function nameOrderIsCaseInsensitive(logger as Test.Logger) as Boolean {
    // "apple" (lower) must sort before "Banana" (upper); a case-sensitive
    // code-point sort would put "Banana" first.
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.one", "light.two"] } },
        "lights" => {
            "light.one" => { "state" => false, "name" => "Banana" },
            "light.two" => { "state" => false, "name" => "apple" }
        }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights[0], "light.two");   // "apple"
    Test.assertEqual(lights[1], "light.one");   // "Banana"
    return true;
}

(:test)
function equalNamesBreakTieOnId(logger as Test.Logger) as Boolean {
    // Two lights share the name "Lamp"; order falls back to the entity id.
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.b", "light.a"] } },
        "lights" => {
            "light.a" => { "state" => false, "name" => "Lamp" },
            "light.b" => { "state" => false, "name" => "Lamp" }
        }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights[0], "light.a");   // equal names -> id tiebreak
    Test.assertEqual(lights[1], "light.b");
    return true;
}

(:test)
function missingLightsSectionFallsBackToAlpha(logger as Test.Logger) as Boolean {
    // No "lights" section: nothing is a group, no names, ordering is plain
    // alphabetical on id.
    var data = { "areas" => { "area.a" => { "name" => "A",
        "lights" => ["light.c", "light.a", "light.b"] } } };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.a"));
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights.size(), 3);
    Test.assertEqual(lights[0], "light.a");
    Test.assertEqual(lights[1], "light.b");
    Test.assertEqual(lights[2], "light.c");
    return true;
}

(:test)
function nonMapLightsDegradesCleanly(logger as Test.Logger) as Boolean {
    // A malformed "lights" section: nothing is a group, ordering stays alphabetical.
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.b", "light.a"] } },
        "lights" => "nope"
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.a"));
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights[0], "light.a");
    Test.assertEqual(lights[1], "light.b");
    return true;
}

(:test)
function malformedInputYieldsEmptyMap(logger as Test.Logger) as Boolean {
    Test.assert(HomeState.fromTemplateData(null).isEmpty());
    Test.assert(HomeState.fromTemplateData("not a dict").isEmpty());
    return true;
}

(:test)
function ignoresNonStringLightEntries(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.mix" => { "name" => "Mix", "lights" => ["light.ok", 42, null] } } };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.listLightsInArea("area.mix").size(), 1);
    Test.assertEqual(state.listLightsInArea("area.mix")[0], "light.ok");
    return true;
}

(:test)
function parsesStateIntoIsOn(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.kitchen" => { "name" => "Kitchen",
            "lights" => ["light.kitchen", "light.pantry"] } },
        "lights" => {
            "light.kitchen" => { "state" => true },
            "light.pantry" => { "state" => false }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isOn("light.kitchen"));
    Test.assert(!state.isOn("light.pantry"));
    return true;
}

(:test)
function missingLightsKeyDegradesToAllOff(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } } };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    return true;
}

(:test)
function nonDictionaryLightEntryDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } },
        "lights" => { "light.hall" => "nope" }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    return true;
}

(:test)
function dropsNonBooleanStateValue(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall", "light.porch"] } },
        "lights" => {
            "light.hall" => { "state" => "on" },
            "light.porch" => { "state" => true }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    Test.assert(state.isOn("light.porch"));
    return true;
}

(:test)
function sensorWithNonNumericStateHasNoReadingValue(logger as Test.Logger) as Boolean {
    // A sensor whose state is neither Float nor Number degrades to a Boolean in
    // the value slot (like a light). getReadingValue must reject it as null so
    // the Boolean can never flow into the numeric floor-mean and crash it.
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.bad", "sensor.good"] } },
        "sensors" => {
            "sensor.bad" => { "state" => "warm", "display_state" => "warm", "device_class" => "temperature" },
            "sensor.good" => { "state" => 21.0, "display_state" => "21.0 °C", "device_class" => "temperature" }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.getReadingValue("sensor.bad") == null);
    Test.assertEqual(state.getReadingValue("sensor.good") as Float, 21.0);
    return true;
}

(:test)
function parsesAvailableIntoIsAvailable(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.kitchen" => { "name" => "Kitchen",
            "lights" => ["light.kitchen", "light.pantry"] } },
        "lights" => {
            "light.kitchen" => { "state" => false, "available" => true },
            "light.pantry" => { "state" => false, "available" => false }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isAvailable("light.kitchen"));
    Test.assert(!state.isAvailable("light.pantry"));
    return true;
}

(:test)
function missingAvailableEntryDefaultsToAvailable(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } } };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isAvailable("light.hall"));
    Test.assert(state.isAvailable("light.unknown"));
    return true;
}

(:test)
function dropsNonBooleanAvailableValue(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall", "light.porch"] } },
        "lights" => {
            "light.hall" => { "state" => false, "available" => "yes" },
            "light.porch" => { "state" => false, "available" => false }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isAvailable("light.hall"));
    Test.assert(!state.isAvailable("light.porch"));
    return true;
}

(:test)
function ordersAvailableBeforeUnavailable(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => [
            "light.avail_plain", "light.avail_group",
            "light.down_plain", "light.down_group"
        ] } },
        "lights" => {
            "light.avail_group" => { "state" => false, "memberCount" => 2, "available" => true },
            "light.down_group" => { "state" => false, "memberCount" => 3, "available" => false },
            "light.avail_plain" => { "state" => false, "available" => true },
            "light.down_plain" => { "state" => false, "available" => false }
        }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.a");
    Test.assertEqual(lights.size(), 4);
    Test.assertEqual(lights[0], "light.avail_group");
    Test.assertEqual(lights[1], "light.avail_plain");
    Test.assertEqual(lights[2], "light.down_group");
    Test.assertEqual(lights[3], "light.down_plain");
    return true;
}

(:test)
function parsesNameIntoGetName(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] } },
        "lights" => { "light.kitchen" => { "state" => false, "name" => "Kitchen Island" } }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.kitchen"), "Kitchen Island");
    return true;
}

(:test)
function missingNameFallsBackToId(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } } };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function nonDictionaryLightsDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } },
        "lights" => "nope"
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function dropsNonStringNameValue(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall", "light.porch"] } },
        "lights" => {
            "light.hall" => { "state" => false, "name" => 42 },
            "light.porch" => { "state" => false, "name" => "Porch" }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    Test.assertEqual(state.getName("light.porch"), "Porch");
    return true;
}

(:test)
function emptyNameFallsBackToId(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } },
        "lights" => { "light.hall" => { "state" => false, "name" => "" } }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function listsAreaSensorsInPayloadOrder(logger as Test.Logger) as Boolean {
    // The template hands sensors over already grouped by device_class, so the
    // model must preserve that order rather than sorting as it does for lights.
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"],
            "sensors" => ["sensor.zzz_temp", "sensor.aaa_humidity", "sensor.mmm_lux"] } },
        "sensors" => {
            "sensor.zzz_temp" => { "state" => 1.0, "display_state" => "1" },
            "sensor.aaa_humidity" => { "state" => 2.0, "display_state" => "2" },
            "sensor.mmm_lux" => { "state" => 3.0, "display_state" => "3" }
        }
    };
    var sensors = HomeState.fromTemplateData(data).listSensorsInArea("area.hall");
    Test.assertEqual(sensors.size(), 3);
    Test.assertEqual(sensors[0], "sensor.zzz_temp");
    Test.assertEqual(sensors[1], "sensor.aaa_humidity");
    Test.assertEqual(sensors[2], "sensor.mmm_lux");
    return true;
}

(:test)
function readingsAreExposedAsSentByServer(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp"] } },
        "sensors" => {
            "sensor.temp" => { "state" => 24.58, "display_state" => "24.6 C", "unit" => "C" }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getReading("sensor.temp") as String, "24.6 C");
    Test.assertEqual(state.getReadingValue("sensor.temp") as Float, 24.58);
    Test.assertEqual(state.getReadingUnit("sensor.temp") as String, "C");
    return true;
}

(:test)
function sensorNamesAndAvailabilityResolveLikeLights(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp", "sensor.dead"] } },
        "sensors" => {
            "sensor.temp" => { "state" => 1.0, "display_state" => "1", "name" => "Hall Temperature",
                "available" => true },
            "sensor.dead" => { "state" => 1.0, "display_state" => "1", "available" => false }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("sensor.temp"), "Hall Temperature");
    Test.assert(state.isAvailable("sensor.temp"));
    Test.assert(!state.isAvailable("sensor.dead"));
    return true;
}

(:test)
function keepsAreaWithSensorsButNoLights(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp"] } },
        "sensors" => { "sensor.temp" => { "state" => 1.0, "display_state" => "1" } }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual((state.areas.get("area.hall") as Dictionary).get(:name) as String, "Hall");
    Test.assertEqual(state.listLightsInArea("area.hall").size(), 0);
    Test.assertEqual(state.listSensorsInArea("area.hall").size(), 1);
    return true;
}

(:test)
function dropsAreaWithNeitherLightsNorSensors(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.bare" => { "name" => "Bare", "lights" => [] as Array<String>, "sensors" => [] as Array<String> },
            "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] }
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual((state.areas.get("area.hall") as Dictionary).get(:name) as String, "Hall");
    return true;
}

(:test)
function areaWithLightsOnlyHasNoSensors(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.b", "light.a"] } } };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("area.hall");
    Test.assertEqual(lights.size(), 2);
    Test.assertEqual(lights[0], "light.a");
    Test.assertEqual(lights[1], "light.b");
    Test.assertEqual(state.listSensorsInArea("area.hall").size(), 0);
    return true;
}

(:test)
function missingSensorsSectionYieldsNoSensors(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } } };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual(state.listSensorsInArea("area.hall").size(), 0);
    return true;
}

(:test)
function malformedSensorsSectionYieldsNoSensors(logger as Test.Logger) as Boolean {
    var nonDictionary = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } },
        "sensors" => "nope"
    };
    Test.assertEqual(HomeState.fromTemplateData(nonDictionary).listSensorsInArea("area.hall").size(), 0);

    var nonStringEntries = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"],
            "sensors" => ["sensor.ok", 42, null] } },
        "sensors" => { "sensor.ok" => { "state" => 1.0, "display_state" => "1" } }
    };
    var sensors = HomeState.fromTemplateData(nonStringEntries).listSensorsInArea("area.hall");
    Test.assertEqual(sensors.size(), 1);
    Test.assertEqual(sensors[0], "sensor.ok");
    return true;
}

(:test)
function malformedReadingsSectionYieldsNoReadings(logger as Test.Logger) as Boolean {
    var nonDictionary = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp"] } },
        "sensors" => "nope"
    };
    Test.assert(HomeState.fromTemplateData(nonDictionary).getReading("sensor.temp") == null);

    var malformedEntries = {
        "areas" => { "area.hall" => { "name" => "Hall",
            "sensors" => ["sensor.bare", "sensor.nodisplay", "sensor.temp"] } },
        "sensors" => {
            "sensor.bare" => "24.6 C",
            "sensor.nodisplay" => { "state" => 24.6, "unit" => "C" },
            "sensor.temp" => { "state" => 24.58, "display_state" => "24.6 C", "unit" => "C" }
        }
    };
    var state = HomeState.fromTemplateData(malformedEntries);
    Test.assert(state.getReading("sensor.bare") == null);
    Test.assert(state.getReading("sensor.nodisplay") == null);
    Test.assertEqual(state.getReading("sensor.temp") as String, "24.6 C");
    return true;
}

(:test)
function sensorMissingFromSensorsSectionHasNoReading(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp", "sensor.unread"] } },
        "sensors" => { "sensor.temp" => { "state" => 24.58, "display_state" => "24.6 C", "unit" => "C" } }
    };
    Test.assert(HomeState.fromTemplateData(data).getReading("sensor.unread") == null);
    return true;
}

(:test)
function getDeviceClassReturnsThePayloadValue(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp"] } },
        "sensors" => { "sensor.temp" => { "state" => 1.0, "display_state" => "1",
            "device_class" => "temperature" } }
    };
    Test.assertEqual(HomeState.fromTemplateData(data).getDeviceClass("sensor.temp") as String, "temperature");
    return true;
}

(:test)
function getDeviceClassIsNullWhenMissing(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall" } } };
    Test.assert(HomeState.fromTemplateData(data).getDeviceClass("sensor.unknown") == null);
    return true;
}

(:test)
function malformedSensorsSectionYieldsNoDeviceClass(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "sensors" => ["sensor.temp"] } },
        "sensors" => "nope"
    };
    Test.assert(HomeState.fromTemplateData(data).getDeviceClass("sensor.temp") == null);
    return true;
}

(:test)
function buildFloorsOrdersByFloorOrderField(logger as Test.Logger) as Boolean {
    // Floors come out by their :order field (HA's floors() order), not by hash
    // key order and not alphabetically: order 0 leads even though its name
    // "Zeta Floor" sorts after "Attic".
    var data = {
        "areas" => {
            "area.loft" => { "name" => "Loft", "lights" => ["light.loft"] },
            "area.cellar" => { "name" => "Cellar", "lights" => ["light.cellar"] }
        },
        "floors" => {
            "floor.zeta" => { "name" => "Zeta Floor", "order" => 0, "areas" => ["area.loft"] },
            "floor.attic" => { "name" => "Attic", "order" => 1, "areas" => ["area.cellar"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 2);
    Test.assertEqual(grouped[0].get(:name) as String, "Zeta Floor");
    Test.assertEqual(grouped[1].get(:name) as String, "Attic");
    return true;
}

(:test)
function buildFloorsOrderFieldOverridesHashOrder(logger as Test.Logger) as Boolean {
    // The :order field, not key order, decides the sequence: the higher-order
    // floor trails regardless of which key hashes first.
    var data = {
        "areas" => {
            "area.loft" => { "name" => "Loft", "lights" => ["light.loft"] },
            "area.cellar" => { "name" => "Cellar", "lights" => ["light.cellar"] }
        },
        "floors" => {
            "floor.top" => { "name" => "Top", "order" => 5, "areas" => ["area.loft"] },
            "floor.bottom" => { "name" => "Bottom", "order" => 2, "areas" => ["area.cellar"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 2);
    Test.assertEqual(grouped[0].get(:name) as String, "Bottom");
    Test.assertEqual(grouped[1].get(:name) as String, "Top");
    return true;
}

(:test)
function buildFloorsSortsNegativeOrderFirst(logger as Test.Logger) as Boolean {
    // A negative :order sorts ahead of a non-negative one — a numeric compare,
    // not a lexical one that would misplace a "-1" string.
    var data = {
        "areas" => {
            "area.loft" => { "name" => "Loft", "lights" => ["light.loft"] },
            "area.cellar" => { "name" => "Cellar", "lights" => ["light.cellar"] }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.loft"] },
            "floor.basement" => { "name" => "Basement", "order" => -1, "areas" => ["area.cellar"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 2);
    Test.assertEqual(grouped[0].get(:name) as String, "Basement");
    Test.assertEqual(grouped[1].get(:name) as String, "Ground");
    return true;
}

(:test)
function buildFloorsCarriesFloorId(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.loft" => { "name" => "Loft", "lights" => ["light.loft"] },
            "area.cellar" => { "name" => "Cellar", "lights" => ["light.cellar"] }
        },
        "floors" => {
            "floor_upstairs" => { "name" => "Upstairs", "areas" => ["area.loft"] }
        }
    };

    var grouped = HomeState.fromTemplateData(data).buildFloors();

    Test.assertEqual(grouped[0].get(:id) as String, "floor_upstairs");
    // The unfloored trailing bucket (Cellar) carries a null id.
    Test.assert(grouped[1].get(:id) == null);
    return true;
}

(:test)
function buildFloorsSortsAreasByNameWithinAFloor(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.zebra" => { "name" => "Zebra Room", "lights" => ["light.z"] },
            "area.alpha" => { "name" => "Alpha Room", "lights" => ["light.a"] }
        },
        "floors" => {
            "floor.up" => { "name" => "Upstairs", "areas" => ["area.zebra", "area.alpha"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 1);
    var floorAreas = grouped[0].get(:areas) as Array<String>;
    Test.assertEqual(floorAreas[0], "area.alpha");
    Test.assertEqual(floorAreas[1], "area.zebra");
    return true;
}

(:test)
function buildFloorsSurfacesUnflooredAreasAsTrailingBucket(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.k"] },
            "area.garage" => { "name" => "Garage", "lights" => ["light.g"] },
            "area.attic" => { "name" => "Attic", "lights" => ["light.a"] }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground Floor", "areas" => ["area.kitchen"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 2);
    Test.assertEqual(grouped[0].get(:name) as String, "Ground Floor");
    Test.assertEqual((grouped[0].get(:areas) as Array<String>)[0], "area.kitchen");

    Test.assert(grouped[1].get(:name) == null);
    var unfloored = grouped[1].get(:areas) as Array<String>;
    Test.assertEqual(unfloored.size(), 2);
    Test.assertEqual(unfloored[0], "area.attic");
    Test.assertEqual(unfloored[1], "area.garage");
    return true;
}

(:test)
function buildFloorsDropsAFloorWhoseAreasAllHaveNoEntities(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.k"] } },
        "floors" => {
            "floor.ground" => { "name" => "Ground Floor", "areas" => ["area.kitchen"] },
            "floor.empty" => { "name" => "Empty Floor", "areas" => ["area.basement"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 1);
    Test.assertEqual(grouped[0].get(:name) as String, "Ground Floor");
    return true;
}

(:test)
function buildFloorsIsFlatAlphabeticalWhenNoFloors(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.zebra" => { "name" => "Zebra Room", "lights" => ["light.z"] },
            "area.alpha" => { "name" => "Alpha Room", "lights" => ["light.a"] }
        }
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 1);
    Test.assert(grouped[0].get(:name) == null);
    var areasOut = grouped[0].get(:areas) as Array<String>;
    Test.assertEqual(areasOut.size(), 2);
    Test.assertEqual(areasOut[0], "area.alpha");
    Test.assertEqual(areasOut[1], "area.zebra");
    return true;
}

(:test)
function buildFloorsIsEmptyWhenNoAreas(logger as Test.Logger) as Boolean {
    var data = { "areas" => {} as Dictionary };
    Test.assertEqual(HomeState.fromTemplateData(data).buildFloors().size(), 0);
    return true;
}

(:test)
function listLightsInFloorUnionsItsAreasLights(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.bed_a", "light.bed_b"] },
            "area.garage" => { "name" => "Garage", "lights" => ["light.garage"] }
        },
        "floors" => {
            "floor_up" => { "name" => "Upstairs", "areas" => ["area.kitchen", "area.bedroom"] }
        }
    };
    var lights = HomeState.fromTemplateData(data).listLightsInFloor("floor_up");

    // Areas in stored order (Kitchen, Bedroom), lights sorted by name within each.
    Test.assertEqual(lights.size(), 3);
    Test.assertEqual(lights[0], "light.kitchen");
    Test.assertEqual(lights[1], "light.bed_a");
    Test.assertEqual(lights[2], "light.bed_b");
    return true;
}

(:test)
function listLightsInFloorIsEmptyForUnknownFloor(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] } },
        "floors" => { "floor_up" => { "name" => "Upstairs", "areas" => ["area.kitchen"] } }
    };
    Test.assertEqual(HomeState.fromTemplateData(data).listLightsInFloor("floor_nowhere").size(), 0);
    return true;
}

(:test)
function malformedFloorsSectionDegradesToUnflooredList(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } },
        "floors" => "nope"
    };
    var grouped = HomeState.fromTemplateData(data).buildFloors();
    Test.assertEqual(grouped.size(), 1);
    Test.assert(grouped[0].get(:name) == null);
    Test.assertEqual((grouped[0].get(:areas) as Array<String>)[0], "area.hall");
    return true;
}

(:test)
function getAreaNameReturnsTheAreasDisplayName(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "area.hall" => { "name" => "Hall", "lights" => ["light.hall"] } } };
    Test.assertEqual(HomeState.fromTemplateData(data).getAreaName("area.hall"), "Hall");
    return true;
}

(:test)
function getAreaNameFallsBackToIdForUnknownArea(logger as Test.Logger) as Boolean {
    var state = HomeState.fromTemplateData({} as Dictionary);
    Test.assertEqual(state.getAreaName("area.unknown"), "area.unknown");
    return true;
}

(:test)
function memberCountIsAbsentForAPlainLight(logger as Test.Logger) as Boolean {
    // Presence of memberCount is the group signal; a plain light carries none.
    var data = {
        "areas" => { "area.a" => { "name" => "A", "lights" => ["light.plain"] } },
        "lights" => { "light.plain" => { "state" => true, "name" => "Plain", "available" => true } }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.plain"));
    return true;
}

(:test)
function sensorFieldsAreFlatPeers(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "area.a" => { "name" => "A", "sensors" => ["sensor.temp"] } },
        "sensors" => { "sensor.temp" => {
            "state" => 21.5, "display_state" => "21.5 °C", "unit" => "°C",
            "device_class" => "temperature", "name" => "Temp", "available" => true
        } }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getReadingValue("sensor.temp") as Float, 21.5);
    Test.assertEqual(state.getReading("sensor.temp") as String, "21.5 °C");
    Test.assertEqual(state.getReadingUnit("sensor.temp") as String, "°C");
    Test.assertEqual(state.getDeviceClass("sensor.temp") as String, "temperature");
    Test.assertEqual(state.getName("sensor.temp"), "Temp");
    Test.assert(state.isAvailable("sensor.temp"));
    return true;
}
