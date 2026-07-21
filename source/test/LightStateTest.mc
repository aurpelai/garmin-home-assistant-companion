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
        "groups" => ["light.grp"]
    };
    var state = LightState.fromTemplateData(data);
    Test.assert(state.isGroup("light.grp"));
    Test.assert(!state.isGroup("light.plain"));
    Test.assert(!state.isGroup("light.unknown"));
    return true;
}

(:test)
function allLightsOrdersGroupsFirstThenAlpha(logger as Test.Logger) as Boolean {
    // "light.zzz_group" sorts AFTER the plain lights alphabetically but must
    // still come first because it is a group.
    var data = {
        "areas" => { "A" => ["light.apple", "light.zzz_group", "light.mango"] },
        "states" => {},
        "groups" => ["light.zzz_group"]
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
        "groups" => ["light.a_group", "light.b_group"]
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
function nonArrayGroupsDegradesCleanly(logger as Test.Logger) as Boolean {
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
