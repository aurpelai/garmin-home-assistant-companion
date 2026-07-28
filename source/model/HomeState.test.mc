import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure parsing/derivation logic in HomeState.
// Run: monkeyc --unit-test ... then `monkeydo bin/test.prg venu3 -t`.

(:test)
function parsesTemplateData(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "Kitchen" => ["light.kitchen_ceiling", "light.kitchen_counter"],
            "Bedroom" => ["light.bedroom"]
        },
        "states" => {}
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 2);
    // Areas are sorted by name: Bedroom before Kitchen.
    Test.assertEqual(state.areas[0].get(:name) as String, "Bedroom");
    Test.assertEqual(state.areas[1].get(:name) as String, "Kitchen");
    Test.assertEqual((state.listLightsInArea("Kitchen")).size(), 2);
    return true;
}

(:test)
function isEmptyWhenNoAreaHasEntities(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Empty" => [] as Array<String> },
        "states" => {}
    };
    Test.assert(HomeState.fromTemplateData(data).isEmpty());
    Test.assert(!HomeState.fromTemplateData({
        "areas" => { "Hall" => ["light.hall"] },
        "states" => {}
    }).isEmpty());
    return true;
}

(:test)
function isGroupReflectsGroupsSection(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "A" => ["light.grp", "light.plain"] },
        "states" => {},
        "groups" => { "light.grp" => 3 }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isGroup("light.grp"));
    Test.assert(!state.isGroup("light.plain"));
    Test.assert(!state.isGroup("light.unknown"));
    return true;
}

(:test)
function memberCountReflectsGroupsSection(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "A" => ["light.grp"] },
        "states" => {},
        "groups" => { "light.grp" => 4 }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getMemberCount("light.grp"), 4);
    return true;
}

(:test)
function dropsInvalidGroupCounts(logger as Test.Logger) as Boolean {
    // The crash-guard case: a value that is not a valid non-negative integer
    // (null / string / array / negative) drops the entry entirely, so the entity
    // is not a group and carries no count — it renders as a plain row rather than
    // flowing a bad value into the sublabel and crashing the menu.
    var data = {
        "areas" => { "A" => ["light.nullc", "light.strc", "light.arrc", "light.negc", "light.ok"] },
        "states" => {},
        "groups" => {
            "light.nullc" => null,
            "light.strc" => "3",
            "light.arrc" => ["light.a"],
            "light.negc" => -1,
            "light.ok" => 2
        }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.nullc"));
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
        "areas" => { "A" => ["light.apple", "light.zzz_group", "light.mango"] },
        "states" => {},
        "groups" => { "light.zzz_group" => 2 }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("A");
    Test.assertEqual(lights.size(), 3);
    Test.assertEqual(lights[0], "light.zzz_group");   // group first
    Test.assertEqual(lights[1], "light.apple");       // then plain, alphabetical
    Test.assertEqual(lights[2], "light.mango");
    return true;
}

(:test)
function listLightsInAreaOrdersGroupsFirst(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Living" => ["light.lamp", "light.b_group", "light.a_group", "light.ceiling"] },
        "states" => {},
        "groups" => { "light.a_group" => 1, "light.b_group" => 4 }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("Living");
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
        "areas" => { "A" => ["light.aaa", "light.zzz"] },
        "states" => {},
        "names" => { "light.aaa" => "Zebra", "light.zzz" => "Aaa" }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("A");
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
        "areas" => { "A" => ["light.one", "light.two"] },
        "states" => {},
        "names" => { "light.one" => "Banana", "light.two" => "apple" }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("A");
    Test.assertEqual(lights[0], "light.two");   // "apple"
    Test.assertEqual(lights[1], "light.one");   // "Banana"
    return true;
}

(:test)
function equalNamesBreakTieOnId(logger as Test.Logger) as Boolean {
    // Two lights share the name "Lamp"; order falls back to the entity id.
    var data = {
        "areas" => { "A" => ["light.b", "light.a"] },
        "states" => {},
        "names" => { "light.a" => "Lamp", "light.b" => "Lamp" }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("A");
    Test.assertEqual(lights[0], "light.a");   // equal names -> id tiebreak
    Test.assertEqual(lights[1], "light.b");
    return true;
}

(:test)
function missingGroupsKeyFallsBackToAlpha(logger as Test.Logger) as Boolean {
    // No "groups" key: nothing is a group, so ordering is plain alphabetical.
    var data = {
        "areas" => { "A" => ["light.c", "light.a", "light.b"] },
        "states" => {}
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.a"));
    var lights = state.listLightsInArea("A");
    Test.assertEqual(lights.size(), 3);
    Test.assertEqual(lights[0], "light.a");
    Test.assertEqual(lights[1], "light.b");
    Test.assertEqual(lights[2], "light.c");
    return true;
}

(:test)
function nonMapGroupsDegradesCleanly(logger as Test.Logger) as Boolean {
    // A malformed "groups" section: nothing is a group, ordering stays alphabetical.
    var data = {
        "areas" => { "A" => ["light.b", "light.a"] },
        "states" => {},
        "groups" => "nope"
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.a"));
    var lights = state.listLightsInArea("A");
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
    var data = { "areas" => { "Mix" => ["light.ok", 42, null] }, "states" => {} };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.listLightsInArea("Mix").size(), 1);
    Test.assertEqual(state.listLightsInArea("Mix")[0], "light.ok");
    return true;
}

(:test)
function parsesStatesIntoIsOn(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.kitchen", "light.pantry"] },
        "states" => { "light.kitchen" => true, "light.pantry" => false }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isOn("light.kitchen"));
    Test.assert(!state.isOn("light.pantry"));
    return true;
}

(:test)
function missingStatesKeyDegradesToAllOff(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] } };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    return true;
}

(:test)
function nonDictionaryStatesDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => "nope" };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    return true;
}

(:test)
function dropsNonBooleanStateValues(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall", "light.porch"] },
        "states" => { "light.hall" => "on", "light.porch" => true }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    Test.assert(state.isOn("light.porch"));
    return true;
}

(:test)
function parsesAvailableIntoIsAvailable(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.kitchen", "light.pantry"] },
        "states" => {},
        "available" => { "light.kitchen" => true, "light.pantry" => false }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isAvailable("light.kitchen"));
    Test.assert(!state.isAvailable("light.pantry"));
    return true;
}

(:test)
function missingAvailableEntryDefaultsToAvailable(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => {} };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isAvailable("light.hall"));
    Test.assert(state.isAvailable("light.unknown"));
    return true;
}

(:test)
function dropsNonBooleanAvailableValues(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall", "light.porch"] },
        "states" => {},
        "available" => { "light.hall" => "yes", "light.porch" => false }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assert(state.isAvailable("light.hall"));
    Test.assert(!state.isAvailable("light.porch"));
    return true;
}

(:test)
function ordersAvailableBeforeUnavailable(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "A" => [
            "light.avail_plain", "light.avail_group",
            "light.down_plain", "light.down_group"
        ] },
        "states" => {},
        "groups" => { "light.avail_group" => 2, "light.down_group" => 3 },
        "available" => {
            "light.avail_plain" => true, "light.avail_group" => true,
            "light.down_plain" => false, "light.down_group" => false
        }
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("A");
    Test.assertEqual(lights.size(), 4);
    Test.assertEqual(lights[0], "light.avail_group");
    Test.assertEqual(lights[1], "light.avail_plain");
    Test.assertEqual(lights[2], "light.down_group");
    Test.assertEqual(lights[3], "light.down_plain");
    return true;
}

(:test)
function parsesNamesIntoGetName(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.kitchen"] },
        "states" => {},
        "names" => { "light.kitchen" => "Kitchen Island" }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.kitchen"), "Kitchen Island");
    return true;
}

(:test)
function missingNamesKeyFallsBackToId(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => {} };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function nonDictionaryNamesDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => {}, "names" => "nope" };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function dropsNonStringNameValues(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall", "light.porch"] },
        "states" => {},
        "names" => { "light.hall" => 42, "light.porch" => "Porch" }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    Test.assertEqual(state.getName("light.porch"), "Porch");
    return true;
}

(:test)
function emptyNameFallsBackToId(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall"] },
        "states" => {},
        "names" => { "light.hall" => "" }
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function listsAreaSensorsInPayloadOrder(logger as Test.Logger) as Boolean {
    // The template hands sensors over already grouped by kind, so the model must
    // preserve that order rather than sorting as it does for lights.
    var data = {
        "areas" => { "Hall" => ["light.hall"] },
        "sensors" => { "Hall" => ["sensor.zzz_temp", "sensor.aaa_humidity", "sensor.mmm_lux"] },
        "states" => {}
    };
    var sensors = HomeState.fromTemplateData(data).listSensorsInArea("Hall");
    Test.assertEqual(sensors.size(), 3);
    Test.assertEqual(sensors[0], "sensor.zzz_temp");
    Test.assertEqual(sensors[1], "sensor.aaa_humidity");
    Test.assertEqual(sensors[2], "sensor.mmm_lux");
    return true;
}

(:test)
function readingsAreExposedAsSentByServer(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp"] },
        "states" => {},
        "readings" => { "sensor.temp" => { "value" => 24.58, "display" => "24.6 C", "unit" => "C" } }
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
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp", "sensor.dead"] },
        "states" => {},
        "names" => { "sensor.temp" => "Hall Temperature" },
        "available" => { "sensor.temp" => true, "sensor.dead" => false }
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
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp"] },
        "states" => {}
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual(state.areas[0].get(:name) as String, "Hall");
    Test.assertEqual(state.listLightsInArea("Hall").size(), 0);
    Test.assertEqual(state.listSensorsInArea("Hall").size(), 1);
    return true;
}

(:test)
function dropsAreaWithNeitherLightsNorSensors(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Bare" => [] as Array<String>, "Hall" => ["light.hall"] },
        "sensors" => { "Bare" => [] as Array<String>, "Hall" => [] as Array<String> },
        "states" => {}
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual(state.areas[0].get(:name) as String, "Hall");
    return true;
}

(:test)
function areaWithLightsOnlyHasNoSensors(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.b", "light.a"] },
        "sensors" => { "Hall" => [] as Array<String> },
        "states" => {}
    };
    var state = HomeState.fromTemplateData(data);
    var lights = state.listLightsInArea("Hall");
    Test.assertEqual(lights.size(), 2);
    Test.assertEqual(lights[0], "light.a");
    Test.assertEqual(lights[1], "light.b");
    Test.assertEqual(state.listSensorsInArea("Hall").size(), 0);
    return true;
}

(:test)
function missingSensorsSectionYieldsNoSensors(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => {} };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual(state.listSensorsInArea("Hall").size(), 0);
    return true;
}

(:test)
function malformedSensorsSectionYieldsNoSensors(logger as Test.Logger) as Boolean {
    var nonDictionary = {
        "areas" => { "Hall" => ["light.hall"] },
        "sensors" => "nope",
        "states" => {}
    };
    Test.assertEqual(HomeState.fromTemplateData(nonDictionary).listSensorsInArea("Hall").size(), 0);

    var nonStringEntries = {
        "areas" => { "Hall" => ["light.hall"] },
        "sensors" => { "Hall" => ["sensor.ok", 42, null] },
        "states" => {}
    };
    var sensors = HomeState.fromTemplateData(nonStringEntries).listSensorsInArea("Hall");
    Test.assertEqual(sensors.size(), 1);
    Test.assertEqual(sensors[0], "sensor.ok");
    return true;
}

(:test)
function malformedReadingsSectionYieldsNoReadings(logger as Test.Logger) as Boolean {
    var nonDictionary = {
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp"] },
        "states" => {},
        "readings" => "nope"
    };
    Test.assert(HomeState.fromTemplateData(nonDictionary).getReading("sensor.temp") == null);

    var malformedEntries = {
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.bare", "sensor.nodisplay", "sensor.temp"] },
        "states" => {},
        "readings" => {
            "sensor.bare" => "24.6 C",
            "sensor.nodisplay" => { "value" => 24.6, "unit" => "C" },
            "sensor.temp" => { "value" => 24.58, "display" => "24.6 C", "unit" => "C" }
        }
    };
    var state = HomeState.fromTemplateData(malformedEntries);
    Test.assert(state.getReading("sensor.bare") == null);
    Test.assert(state.getReading("sensor.nodisplay") == null);
    Test.assertEqual(state.getReading("sensor.temp") as String, "24.6 C");
    return true;
}

(:test)
function sensorMissingFromReadingsHasNoReading(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp", "sensor.unread"] },
        "states" => {},
        "readings" => { "sensor.temp" => { "value" => 24.58, "display" => "24.6 C", "unit" => "C" } }
    };
    Test.assert(HomeState.fromTemplateData(data).getReading("sensor.unread") == null);
    return true;
}

(:test)
function getKindReturnsThePayloadKind(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp"] },
        "states" => {},
        "kinds" => { "sensor.temp" => "temperature" }
    };
    Test.assertEqual(HomeState.fromTemplateData(data).getKind("sensor.temp") as String, "temperature");
    return true;
}

(:test)
function getKindIsNullWhenMissing(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => [] as Array<String> }, "states" => {} };
    Test.assert(HomeState.fromTemplateData(data).getKind("sensor.unknown") == null);
    return true;
}

(:test)
function malformedKindsSectionYieldsNoKinds(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => [] as Array<String> },
        "sensors" => { "Hall" => ["sensor.temp"] },
        "states" => {},
        "kinds" => "nope"
    };
    Test.assert(HomeState.fromTemplateData(data).getKind("sensor.temp") == null);
    return true;
}

(:test)
function buildFloorGroupsPreservesFloorsKeyOrder(logger as Test.Logger) as Boolean {
    // Floors must come out in input order, never re-sorted, even though "Zeta"
    // sorts after "Attic" alphabetically.
    var data = {
        "areas" => { "Loft" => ["light.loft"], "Cellar" => ["light.cellar"] },
        "states" => {},
        "floors" => [
            { "name" => "Zeta Floor", "areas" => ["Loft"] },
            { "name" => "Attic", "areas" => ["Cellar"] }
        ]
    };
    var grouped = HomeState.fromTemplateData(data).buildFloorGroups();
    Test.assertEqual(grouped.size(), 2);
    Test.assertEqual(grouped[0].get(:name) as String, "Zeta Floor");
    Test.assertEqual(grouped[1].get(:name) as String, "Attic");
    return true;
}

(:test)
function buildFloorGroupsSortsAreasAlphabeticallyWithinAFloor(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Zebra Room" => ["light.z"], "Alpha Room" => ["light.a"] },
        "states" => {},
        "floors" => [
            { "name" => "Upstairs", "areas" => ["Zebra Room", "Alpha Room"] }
        ]
    };
    var grouped = HomeState.fromTemplateData(data).buildFloorGroups();
    Test.assertEqual(grouped.size(), 1);
    var floorAreas = grouped[0].get(:areas) as Array<String>;
    Test.assertEqual(floorAreas[0], "Alpha Room");
    Test.assertEqual(floorAreas[1], "Zebra Room");
    return true;
}

(:test)
function buildFloorGroupsSurfacesUnflooredAreasAsTrailingBucket(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.k"], "Garage" => ["light.g"], "Attic" => ["light.a"] },
        "states" => {},
        "floors" => [
            { "name" => "Ground Floor", "areas" => ["Kitchen"] }
        ]
    };
    var grouped = HomeState.fromTemplateData(data).buildFloorGroups();
    Test.assertEqual(grouped.size(), 2);
    Test.assertEqual(grouped[0].get(:name) as String, "Ground Floor");
    Test.assertEqual((grouped[0].get(:areas) as Array<String>)[0], "Kitchen");

    Test.assert(grouped[1].get(:name) == null);
    var unfloored = grouped[1].get(:areas) as Array<String>;
    Test.assertEqual(unfloored.size(), 2);
    Test.assertEqual(unfloored[0], "Attic");
    Test.assertEqual(unfloored[1], "Garage");
    return true;
}

(:test)
function buildFloorGroupsDropsAFloorWhoseAreasAllHaveNoEntities(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.k"] },
        "states" => {},
        "floors" => [
            { "name" => "Ground Floor", "areas" => ["Kitchen"] },
            { "name" => "Empty Floor", "areas" => ["Basement"] }
        ]
    };
    var grouped = HomeState.fromTemplateData(data).buildFloorGroups();
    Test.assertEqual(grouped.size(), 1);
    Test.assertEqual(grouped[0].get(:name) as String, "Ground Floor");
    return true;
}

(:test)
function buildFloorGroupsIsFlatAlphabeticalWhenNoFloors(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Zebra Room" => ["light.z"], "Alpha Room" => ["light.a"] },
        "states" => {}
    };
    var grouped = HomeState.fromTemplateData(data).buildFloorGroups();
    Test.assertEqual(grouped.size(), 1);
    Test.assert(grouped[0].get(:name) == null);
    var areasOut = grouped[0].get(:areas) as Array<String>;
    Test.assertEqual(areasOut.size(), 2);
    Test.assertEqual(areasOut[0], "Alpha Room");
    Test.assertEqual(areasOut[1], "Zebra Room");
    return true;
}

(:test)
function buildFloorGroupsIsEmptyWhenNoAreas(logger as Test.Logger) as Boolean {
    var data = { "areas" => {} as Dictionary, "states" => {} };
    Test.assertEqual(HomeState.fromTemplateData(data).buildFloorGroups().size(), 0);
    return true;
}

(:test)
function malformedFloorsSectionDegradesToUnflooredList(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall"] },
        "states" => {},
        "floors" => "nope"
    };
    var grouped = HomeState.fromTemplateData(data).buildFloorGroups();
    Test.assertEqual(grouped.size(), 1);
    Test.assert(grouped[0].get(:name) == null);
    Test.assertEqual((grouped[0].get(:areas) as Array<String>)[0], "Hall");
    return true;
}
