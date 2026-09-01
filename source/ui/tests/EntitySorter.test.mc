import Toybox.Lang;
import Toybox.Test;

(:test)
module EntitySorterTest {

    function light(id as String, name as String, available as Boolean,
                   memberIds as Array<String> or Null) as LightModel {
        return new LightModel(id, false, name, available, "area.a", memberIds);
    }

    function fan(id as String, name as String, available as Boolean,
                 memberIds as Array<String> or Null) as FanModel {
        return new FanModel(id, false, name, available, "area.a", memberIds, null);
    }

    function sensor(id as String, deviceClass as String) as SensorModel {
        return new SensorModel(id, "1", deviceClass, id, true, "area.a");
    }

    function area(id as String, name as String) as AreaModel {
        return new AreaModel(id, name);
    }
}

(:test)
function lightsAreSortedAvailableFirstThenGroupsThenByName(logger as Test.Logger) as Boolean {
    var sorted = EntitySorter.sortToggleables([
        EntitySorterTest.light("light.dark", "Aaa Broken", false, null),
        EntitySorterTest.light("light.aaa", "Aaa", true, null),
        EntitySorterTest.light("light.mid", "Ähtäri", true, null),
        EntitySorterTest.light("light.zzz_group", "Zzz", true, ["light.aaa"])
    ] as Array<ToggleableModel>);

    Test.assertEqual(sorted.size(), 4);
    Test.assertEqual(sorted[0].id, "light.zzz_group");
    Test.assertEqual(sorted[1].id, "light.aaa");
    Test.assertEqual(sorted[2].id, "light.mid");
    Test.assertEqual(sorted[3].id, "light.dark");
    return true;
}

(:test)
function fansAreSortedByTheSameRulesAsLights(logger as Test.Logger) as Boolean {
    var sorted = EntitySorter.sortToggleables([
        EntitySorterTest.fan("fan.dark", "Aaa Broken", false, null),
        EntitySorterTest.fan("fan.aaa", "Aaa", true, null),
        EntitySorterTest.fan("fan.mid", "Ähtäri", true, null),
        EntitySorterTest.fan("fan.zzz_group", "Zzz", true, ["fan.aaa"])
    ] as Array<ToggleableModel>);

    Test.assertEqual(sorted.size(), 4);
    Test.assertEqual(sorted[0].id, "fan.zzz_group");
    Test.assertEqual(sorted[1].id, "fan.aaa");
    Test.assertEqual(sorted[2].id, "fan.mid");
    Test.assertEqual(sorted[3].id, "fan.dark");
    return true;
}

(:test)
function anUnavailableGroupLeadsItsBucketEvenWithNoReachableMembers(logger as Test.Logger) as Boolean {
    var sorted = EntitySorter.sortToggleables([
        EntitySorterTest.light("light.dark", "Aaa Broken", false, null),
        EntitySorterTest.light("light.dead_group", "Zzz Group", false, [] as Array<String>)
    ] as Array<ToggleableModel>);

    Test.assertEqual(sorted[0].id, "light.dead_group");
    Test.assertEqual(sorted[1].id, "light.dark");
    return true;
}

(:test)
function lightsWithEqualNamesAreSortedByIdRatherThanArbitrarily(logger as Test.Logger) as Boolean {
    var sorted = EntitySorter.sortToggleables([
        EntitySorterTest.light("light.b", "Lampe", true, null),
        EntitySorterTest.light("light.a", "Lampe", true, null)
    ] as Array<ToggleableModel>);

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
function sortingLeavesTheCallersOwnArrayInItsOriginalOrder(logger as Test.Logger) as Boolean {
    var areas = [
        EntitySorterTest.area("area.alpha", "Ülkerum"),
        EntitySorterTest.area("area.zulu", "Alcove")
    ];

    EntitySorter.sortAreas(areas);

    Test.assertEqual(areas[0].id, "area.alpha");
    Test.assertEqual(areas[1].id, "area.zulu");
    return true;
}

(:test)
function sensorsAreGroupedByDeviceClass(logger as Test.Logger) as Boolean {
    var grouped = EntitySorter.groupSensorsByDeviceClass([
        EntitySorterTest.sensor("sensor.lux", "illuminance"),
        EntitySorterTest.sensor("sensor.odd", ""),
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
