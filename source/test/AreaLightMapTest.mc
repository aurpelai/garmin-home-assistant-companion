import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure parsing/derivation logic in AreaLightMap.
// Run: monkeyc --unit-test ... then `monkeydo bin/test.prg venu3 -t`.

(:test)
function parsesTemplateData(logger as Test.Logger) as Boolean {
    var data = {
        "Kitchen" => ["light.kitchen_ceiling", "light.kitchen_counter"],
        "Bedroom" => ["light.bedroom"]
    };
    var map = AreaLightMap.fromTemplateData(data);
    Test.assertEqual(map.areas.size(), 2);
    // Areas are sorted by name: Bedroom before Kitchen.
    Test.assertEqual(map.areas[0].get(:name) as String, "Bedroom");
    Test.assertEqual(map.areas[1].get(:name) as String, "Kitchen");
    Test.assertEqual((map.lightsForArea("Kitchen")).size(), 2);
    return true;
}

(:test)
function skipsAreasWithNoLights(logger as Test.Logger) as Boolean {
    var data = {
        "Empty" => [] as Array<String>,
        "Hall" => ["light.hall"]
    };
    var map = AreaLightMap.fromTemplateData(data);
    Test.assertEqual(map.areas.size(), 1);
    Test.assertEqual(map.areas[0].get(:name) as String, "Hall");
    return true;
}

(:test)
function allLightsDedupesAndSorts(logger as Test.Logger) as Boolean {
    var data = {
        "A" => ["light.b", "light.a"],
        "B" => ["light.a", "light.c"]   // light.a duplicated across areas
    };
    var map = AreaLightMap.fromTemplateData(data);
    var all = map.allLights();
    Test.assertEqual(all.size(), 3);
    Test.assertEqual(all[0], "light.a");
    Test.assertEqual(all[1], "light.b");
    Test.assertEqual(all[2], "light.c");
    return true;
}

(:test)
function malformedInputYieldsEmptyMap(logger as Test.Logger) as Boolean {
    Test.assert(AreaLightMap.fromTemplateData(null).isEmpty());
    Test.assert(AreaLightMap.fromTemplateData("not a dict").isEmpty());
    return true;
}

(:test)
function ignoresNonStringLightEntries(logger as Test.Logger) as Boolean {
    var data = { "Mix" => ["light.ok", 42, null] };
    var map = AreaLightMap.fromTemplateData(data);
    Test.assertEqual(map.lightsForArea("Mix").size(), 1);
    Test.assertEqual(map.lightsForArea("Mix")[0], "light.ok");
    return true;
}
