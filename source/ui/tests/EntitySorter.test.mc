import Toybox.Lang;
import Toybox.Test;

(:test)
module EntitySorterTest {

    function stateWith(lights as Dictionary, sensors as Dictionary) as HaState {
        var haState = new HaState();
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }

    function reading(deviceClass as String) as Dictionary {
        return { "state" => 1.0, "display_state" => "1", "device_class" => deviceClass,
                 "area_id" => "area.a" };
    }
}

(:test)
function lightsAreSortedAvailableFirstThenGroupsThenByName(logger as Test.Logger) as Boolean {
    // Each rank must beat the next: the unavailable group outranks nothing, and
    // the group named last still leads the plain lights.
    var haState = EntitySorterTest.stateWith({
        "light.zzz_group" => { "state" => false, "name" => "Zzz", "available" => true,
            "memberIds" => ["light.aaa"] },
        "light.aaa" => { "state" => false, "name" => "Aaa", "available" => true },
        "light.mid" => { "state" => false, "name" => "Ähtäri", "available" => true },
        "light.dark" => { "state" => false, "name" => "Aaa Broken", "available" => false }
    }, {});

    var sorted = EntitySorter.sortLights(haState,
        ["light.dark", "light.aaa", "light.mid", "light.zzz_group"]);

    Test.assertEqual(sorted.size(), 4);
    Test.assertEqual(sorted[0], "light.zzz_group");
    Test.assertEqual(sorted[1], "light.aaa");
    Test.assertEqual(sorted[2], "light.mid");
    Test.assertEqual(sorted[3], "light.dark");
    return true;
}

(:test)
function lightsWithEqualNamesAreSortedByIdRatherThanArbitrarily(logger as Test.Logger) as Boolean {
    var haState = EntitySorterTest.stateWith({
        "light.b" => { "state" => false, "name" => "Lampe", "available" => true },
        "light.a" => { "state" => false, "name" => "Lampe", "available" => true }
    }, {});

    var sorted = EntitySorter.sortLights(haState, ["light.b", "light.a"]);

    Test.assertEqual(sorted[0], "light.a");
    Test.assertEqual(sorted[1], "light.b");
    return true;
}

(:test)
function areasAreSortedByLabelWithUnknownIdsDropped(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    haState.setZone(HaPayload.parseZone({
        "areas" => {
            "area.zulu" => { "name" => "Alcove" },
            "area.alpha" => { "name" => "Ülkerum" },
            "area.nameless" => {} as Dictionary
        }
    }));
    haState.setAreas(HaPayload.parseAreas({
        "areas" => {
            "area.zulu" => { "name" => "Alcove" },
            "area.alpha" => { "name" => "Ülkerum" },
            "area.nameless" => {} as Dictionary
        }
    }));
    haState.setFloors(HaPayload.parseFloors({
        "areas" => {
            "area.zulu" => { "name" => "Alcove" },
            "area.alpha" => { "name" => "Ülkerum" },
            "area.nameless" => {} as Dictionary
        }
    }));

    var sorted = EntitySorter.sortAreas(haState,
        ["area.alpha", "area.ghost", "area.nameless", "area.zulu"]);

    Test.assertEqual(sorted.size(), 3);
    Test.assertEqual(sorted[0], "area.zulu");
    Test.assertEqual(sorted[1], "area.nameless");
    Test.assertEqual(sorted[2], "area.alpha");
    return true;
}

(:test)
function sensorsAreGroupedByDeviceClass(logger as Test.Logger) as Boolean {
    var haState = EntitySorterTest.stateWith({}, {
        "sensor.lux" => EntitySorterTest.reading("illuminance"),
        "sensor.temp" => EntitySorterTest.reading("temperature"),
        "sensor.rh" => EntitySorterTest.reading("humidity"),
        "sensor.odd" => EntitySorterTest.reading("pressure")
    });

    var grouped = EntitySorter.groupSensorsByDeviceClass(haState,
        ["sensor.lux", "sensor.odd", "sensor.rh", "sensor.temp"]);

    Test.assertEqual(grouped.size(), 4);
    Test.assertEqual(grouped[0], "sensor.temp");
    Test.assertEqual(grouped[1], "sensor.rh");
    Test.assertEqual(grouped[2], "sensor.lux");
    Test.assertEqual(grouped[3], "sensor.odd");
    return true;
}
