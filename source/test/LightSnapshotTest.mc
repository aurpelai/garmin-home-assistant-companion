import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure parsing/derivation logic in LightSnapshot.
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
    var snap = LightSnapshot.fromTemplateData(data);
    Test.assertEqual(snap.areas.size(), 2);
    // Areas are sorted by name: Bedroom before Kitchen.
    Test.assertEqual(snap.areas[0].get(:name) as String, "Bedroom");
    Test.assertEqual(snap.areas[1].get(:name) as String, "Kitchen");
    Test.assertEqual((snap.lightsForArea("Kitchen")).size(), 2);
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
    var snap = LightSnapshot.fromTemplateData(data);
    Test.assertEqual(snap.areas.size(), 1);
    Test.assertEqual(snap.areas[0].get(:name) as String, "Hall");
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
    var snap = LightSnapshot.fromTemplateData(data);
    var all = snap.allLights();
    Test.assertEqual(all.size(), 3);
    Test.assertEqual(all[0], "light.a");
    Test.assertEqual(all[1], "light.b");
    Test.assertEqual(all[2], "light.c");
    return true;
}

(:test)
function malformedInputYieldsEmptyMap(logger as Test.Logger) as Boolean {
    Test.assert(LightSnapshot.fromTemplateData(null).isEmpty());
    Test.assert(LightSnapshot.fromTemplateData("not a dict").isEmpty());
    return true;
}

(:test)
function ignoresNonStringLightEntries(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Mix" => ["light.ok", 42, null] }, "states" => {} };
    var snap = LightSnapshot.fromTemplateData(data);
    Test.assertEqual(snap.lightsForArea("Mix").size(), 1);
    Test.assertEqual(snap.lightsForArea("Mix")[0], "light.ok");
    return true;
}

(:test)
function parsesStatesIntoIsOn(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Kitchen" => ["light.kitchen", "light.pantry"] },
        "states" => { "light.kitchen" => true, "light.pantry" => false }
    };
    var snap = LightSnapshot.fromTemplateData(data);
    Test.assert(snap.isOn("light.kitchen"));
    Test.assert(!snap.isOn("light.pantry"));
    return true;
}

(:test)
function missingStatesKeyDegradesToAllOff(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] } };
    var snap = LightSnapshot.fromTemplateData(data);
    // Unknown entity reads as off.
    Test.assert(!snap.isOn("light.hall"));
    return true;
}

(:test)
function nonDictionaryStatesDegradesCleanly(logger as Test.Logger) as Boolean {
    var data = { "areas" => { "Hall" => ["light.hall"] }, "states" => "nope" };
    var snap = LightSnapshot.fromTemplateData(data);
    Test.assert(!snap.isOn("light.hall"));
    return true;
}

(:test)
function dropsNonBooleanStateValues(logger as Test.Logger) as Boolean {
    var data = {
        "areas" => { "Hall" => ["light.hall", "light.porch"] },
        "states" => { "light.hall" => "on", "light.porch" => true }
    };
    var snap = LightSnapshot.fromTemplateData(data);
    // "on" (a String, not a Boolean) is dropped -> reads as off.
    Test.assert(!snap.isOn("light.hall"));
    Test.assert(snap.isOn("light.porch"));
    return true;
}
