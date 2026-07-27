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
function skipsAreasWithNoLights(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "Empty" => [] as Array<String>,
            "Hall" => ["light.hall"]
        },
        "states" => {}
    };
    var state = HomeState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual(state.areas[0].get(:name) as String, "Hall");
    return true;
}

(:test)
function isEmptyWhenNoAreaHasLights(logger as Test.Logger) as Boolean {
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
