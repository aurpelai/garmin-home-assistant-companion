import Toybox.Lang;
import Toybox.Test;

(:test)
module DisplayOrderTest {

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
function lightsOrderAvailableFirstThenGroupsThenByName(logger as Test.Logger) as Boolean {
    // Each rank must beat the next: the unavailable group outranks nothing, and
    // the group named last still leads the plain lights.
    var haState = DisplayOrderTest.stateWith({
        "light.zzz_group" => { "state" => false, "name" => "Zzz", "available" => true,
            "memberIds" => ["light.aaa"] },
        "light.aaa" => { "state" => false, "name" => "Aaa", "available" => true },
        "light.mid" => { "state" => false, "name" => "Ähtäri", "available" => true },
        "light.dark" => { "state" => false, "name" => "Aaa Broken", "available" => false }
    }, {});

    var ordered = DisplayOrder.orderLightIds(haState,
        ["light.dark", "light.aaa", "light.mid", "light.zzz_group"]);

    Test.assertEqual(ordered.size(), 4);
    Test.assertEqual(ordered[0], "light.zzz_group");
    Test.assertEqual(ordered[1], "light.aaa");
    Test.assertEqual(ordered[2], "light.mid");
    Test.assertEqual(ordered[3], "light.dark");
    return true;
}

(:test)
function lightsWithEqualNamesOrderByIdRatherThanArbitrarily(logger as Test.Logger) as Boolean {
    var haState = DisplayOrderTest.stateWith({
        "light.b" => { "state" => false, "name" => "Lampe", "available" => true },
        "light.a" => { "state" => false, "name" => "Lampe", "available" => true }
    }, {});

    var ordered = DisplayOrder.orderLightIds(haState, ["light.b", "light.a"]);

    Test.assertEqual(ordered[0], "light.a");
    Test.assertEqual(ordered[1], "light.b");
    return true;
}

(:test)
function areasOrderByNameAndDropAnIdTheStructureNeverReported(logger as Test.Logger) as Boolean {
    // A floor's area list can name an area the areas section never carried, and
    // ordering is by the label on screen rather than by the id behind it. An
    // unnamed area falls back to its id, which is what a reader sees.
    var haState = new HaState();
    haState.setStructure(HaPayload.parseStructure({
        "areas" => {
            "area.zulu" => { "name" => "Alcove" },
            "area.alpha" => { "name" => "Ülkerum" },
            "area.nameless" => {} as Dictionary
        }
    }));

    var ordered = DisplayOrder.orderAreaIds(haState,
        ["area.alpha", "area.ghost", "area.nameless", "area.zulu"]);

    Test.assertEqual(ordered.size(), 3);
    Test.assertEqual(ordered[0], "area.zulu");
    Test.assertEqual(ordered[1], "area.nameless");
    Test.assertEqual(ordered[2], "area.alpha");
    return true;
}

(:test)
function sensorsGroupByDeviceClassInTheOrderTheTemplateUsedTo(logger as Test.Logger) as Boolean {
    var haState = DisplayOrderTest.stateWith({}, {
        "sensor.lux" => DisplayOrderTest.reading("illuminance"),
        "sensor.temp" => DisplayOrderTest.reading("temperature"),
        "sensor.rh" => DisplayOrderTest.reading("humidity"),
        "sensor.odd" => DisplayOrderTest.reading("pressure")
    });

    var ordered = DisplayOrder.groupSensorIdsByDeviceClass(haState,
        ["sensor.lux", "sensor.odd", "sensor.rh", "sensor.temp"]);

    Test.assertEqual(ordered.size(), 4);
    Test.assertEqual(ordered[0], "sensor.temp");
    Test.assertEqual(ordered[1], "sensor.rh");
    Test.assertEqual(ordered[2], "sensor.lux");
    Test.assertEqual(ordered[3], "sensor.odd");
    return true;
}
