import Toybox.Lang;
import Toybox.Test;

(:test)
module EntitySorterTest {

    function light(id as String, name as String, available as Boolean,
                   memberIds as Array<String> or Null) as LightModel {
        return new LightModel(id, false, name, available, "area.a", memberIds);
    }

    function sensor(id as String, deviceClass as String) as SensorModel {
        return new SensorModel(id, 1.0, "1", null, deviceClass, id, true, "area.a");
    }

    function area(id as String, name as String) as AreaModel {
        return new AreaModel(id, name);
    }
}

(:test)
function lightsAreSortedAvailableFirstThenGroupsThenByName(logger as Test.Logger) as Boolean {
    // Each rank must beat the next: the unavailable group outranks nothing, and
    // the group named last still leads the plain lights.
    var sorted = EntitySorter.sortLights([
        EntitySorterTest.light("light.dark", "Aaa Broken", false, null),
        EntitySorterTest.light("light.aaa", "Aaa", true, null),
        EntitySorterTest.light("light.mid", "Ähtäri", true, null),
        EntitySorterTest.light("light.zzz_group", "Zzz", true, ["light.aaa"])
    ]);

    Test.assertEqual(sorted.size(), 4);
    Test.assertEqual(sorted[0].id, "light.zzz_group");
    Test.assertEqual(sorted[1].id, "light.aaa");
    Test.assertEqual(sorted[2].id, "light.mid");
    Test.assertEqual(sorted[3].id, "light.dark");
    return true;
}

(:test)
function lightsWithEqualNamesAreSortedByIdRatherThanArbitrarily(logger as Test.Logger) as Boolean {
    var sorted = EntitySorter.sortLights([
        EntitySorterTest.light("light.b", "Lampe", true, null),
        EntitySorterTest.light("light.a", "Lampe", true, null)
    ]);

    Test.assertEqual(sorted[0].id, "light.a");
    Test.assertEqual(sorted[1].id, "light.b");
    return true;
}

(:test)
function areasAreSortedByName(logger as Test.Logger) as Boolean {
    var sorted = EntitySorter.sortAreas([
        EntitySorterTest.area("area.alpha", "Ülkerum"),
        EntitySorterTest.area("area.zulu", "Alcove")
    ]);

    Test.assertEqual(sorted.size(), 2);
    Test.assertEqual(sorted[0].id, "area.zulu");
    Test.assertEqual(sorted[1].id, "area.alpha");
    return true;
}

(:test)
function sensorsAreGroupedByDeviceClass(logger as Test.Logger) as Boolean {
    var grouped = EntitySorter.groupSensorsByDeviceClass([
        EntitySorterTest.sensor("sensor.lux", "illuminance"),
        EntitySorterTest.sensor("sensor.odd", "pressure"),
        EntitySorterTest.sensor("sensor.rh", "humidity"),
        EntitySorterTest.sensor("sensor.temp", "temperature")
    ]);

    Test.assertEqual(grouped.size(), 4);
    Test.assertEqual(grouped[0].id, "sensor.temp");
    Test.assertEqual(grouped[1].id, "sensor.rh");
    Test.assertEqual(grouped[2].id, "sensor.lux");
    Test.assertEqual(grouped[3].id, "sensor.odd");
    return true;
}
