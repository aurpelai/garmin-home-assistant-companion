import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure parsing/derivation logic in LightState.
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
    var state = LightState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 2);
    // Areas are sorted by name: Bedroom before Kitchen.
    Test.assertEqual(state.areas[0].get(:name) as String, "Bedroom");
    Test.assertEqual(state.areas[1].get(:name) as String, "Kitchen");
    Test.assertEqual((state.lightsForArea("Kitchen")).size(), 2);
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
    var state = LightState.fromTemplateData(data);
    Test.assertEqual(state.areas.size(), 1);
    Test.assertEqual(state.areas[0].get(:name) as String, "Hall");
    return true;
}

(:test)
function allLightsDedupesAndSorts(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => {
            "A" => ["light.b", "light.a"],
            "B" => ["light.a", "light.c"]   // light.a duplicated across areas
        },
        "states" => {}
    };
    var state = LightState.fromTemplateData(data);
    var all = state.allLights();
    Test.assertEqual(all.size(), 3);
    Test.assertEqual(all[0], "light.a");
    Test.assertEqual(all[1], "light.b");
    Test.assertEqual(all[2], "light.c");
    return true;
}

(:test)
function isGroupReflectsGroupsSection(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "A" => ["light.grp", "light.plain"] },
        "states" => {},
        "groups" => { "light.grp" => 3 }
    };
    var state = LightState.fromTemplateData(data);
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
    var state = LightState.fromTemplateData(data);
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
    var state = LightState.fromTemplateData(data);
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
function allLightsOrdersGroupsFirstThenAlpha(logger as Test.Logger) as Boolean {
    // "light.zzz_group" sorts AFTER the plain lights alphabetically but must
    // still come first because it is a group.
    var data = {
        "areas" => { "A" => ["light.apple", "light.zzz_group", "light.mango"] },
        "states" => {},
        "groups" => { "light.zzz_group" => 2 }
    };
    var state = LightState.fromTemplateData(data);
    var all = state.allLights();
    Test.assertEqual(all.size(), 3);
    Test.assertEqual(all[0], "light.zzz_group");   // group first
    Test.assertEqual(all[1], "light.apple");       // then plain, alphabetical
    Test.assertEqual(all[2], "light.mango");
    return true;
}

(:test)
function lightsForAreaOrdersGroupsFirst(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Living" => ["light.lamp", "light.b_group", "light.a_group", "light.ceiling"] },
        "states" => {},
        "groups" => { "light.a_group" => 1, "light.b_group" => 4 }
    };
    var state = LightState.fromTemplateData(data);
    var lights = state.lightsForArea("Living");
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
    var state = LightState.fromTemplateData(data);
    var all = state.allLights();
    Test.assertEqual(all.size(), 2);
    Test.assertEqual(all[0], "light.zzz");   // name "Aaa" first
    Test.assertEqual(all[1], "light.aaa");   // name "Zebra" second
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
    var state = LightState.fromTemplateData(data);
    var all = state.allLights();
    Test.assertEqual(all[0], "light.two");   // "apple"
    Test.assertEqual(all[1], "light.one");   // "Banana"
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
    var state = LightState.fromTemplateData(data);
    var all = state.allLights();
    Test.assertEqual(all[0], "light.a");   // equal names -> id tiebreak
    Test.assertEqual(all[1], "light.b");
    return true;
}

(:test)
function missingGroupsKeyFallsBackToAlpha(logger as Test.Logger) as Boolean {
    // No "groups" key: nothing is a group, so ordering is plain alphabetical.
    var data = {
        "areas" => { "A" => ["light.c", "light.a", "light.b"] },
        "states" => {}
    };
    var state = LightState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.a"));
    var all = state.allLights();
    Test.assertEqual(all.size(), 3);
    Test.assertEqual(all[0], "light.a");
    Test.assertEqual(all[1], "light.b");
    Test.assertEqual(all[2], "light.c");
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
    var state = LightState.fromTemplateData(data);
    Test.assert(!state.isGroup("light.a"));
    var all = state.allLights();
    Test.assertEqual(all[0], "light.a");
    Test.assertEqual(all[1], "light.b");
    return true;
}

(:test)
function malformedInputYieldsEmptyMap(logger as Test.Logger) as Boolean {
    Test.assert(LightState.fromTemplateData(null).isEmpty());
    Test.assert(LightState.fromTemplateData("not a dict").isEmpty());
    return true;
}

(:test)
function ignoresNonStringLightEntries(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Mix" => ["light.ok", 42, null] }, "states" => {} };
    var state = LightState.fromTemplateData(data);
    Test.assertEqual(state.lightsForArea("Mix").size(), 1);
    Test.assertEqual(state.lightsForArea("Mix")[0], "light.ok");
    return true;
}

(:test)
function parsesStatesIntoIsOn(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.kitchen", "light.pantry"] },
        "states" => { "light.kitchen" => true, "light.pantry" => false }
    };
    var state = LightState.fromTemplateData(data);
    Test.assert(state.isOn("light.kitchen"));
    Test.assert(!state.isOn("light.pantry"));
    return true;
}

(:test)
function missingStatesKeyDegradesToAllOff(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] } };
    var state = LightState.fromTemplateData(data);
    // Unknown entity reads as off.
    Test.assert(!state.isOn("light.hall"));
    return true;
}

(:test)
function nonDictionaryStatesDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => "nope" };
    var state = LightState.fromTemplateData(data);
    Test.assert(!state.isOn("light.hall"));
    return true;
}

(:test)
function dropsNonBooleanStateValues(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall", "light.porch"] },
        "states" => { "light.hall" => "on", "light.porch" => true }
    };
    var state = LightState.fromTemplateData(data);
    // "on" (a String, not a Boolean) is dropped -> reads as off.
    Test.assert(!state.isOn("light.hall"));
    Test.assert(state.isOn("light.porch"));
    return true;
}

(:test)
function parsesNamesIntoGetName(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.kitchen"] },
        "states" => {},
        "names" => { "light.kitchen" => "Kitchen Island" }
    };
    var state = LightState.fromTemplateData(data);
    Test.assertEqual(state.getName("light.kitchen"), "Kitchen Island");
    return true;
}

(:test)
function missingNamesKeyFallsBackToId(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => {} };
    var state = LightState.fromTemplateData(data);
    // No "names" section: getName returns the bare id.
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}

(:test)
function nonDictionaryNamesDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => {}, "names" => "nope" };
    var state = LightState.fromTemplateData(data);
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
    var state = LightState.fromTemplateData(data);
    // 42 (not a String) is dropped -> getName falls back to the id.
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
    var state = LightState.fromTemplateData(data);
    // Empty string counts as no name.
    Test.assertEqual(state.getName("light.hall"), "light.hall");
    return true;
}
