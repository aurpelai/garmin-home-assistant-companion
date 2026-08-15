import Toybox.Lang;
import Toybox.Test;

(:test)
module HaPayloadTest {

    function lightsPayload(entries as Dictionary) as Dictionary {
        return { "lights" => entries };
    }

    // The three writes the structure target makes, as the coordinator makes them.
    function applyStructure(haState as HaState, payload as Dictionary) as Void {
        haState.setZone(HaPayload.parseZone(payload));
        haState.setAreas(HaPayload.parseAreas(payload));
        haState.setFloors(HaPayload.parseFloors(payload));
    }

    function sensorsPayload(entries as Dictionary) as Dictionary {
        return { "sensors" => entries };
    }

    function reading(state as Object or Null, displayValue as Object or Null, areaId as String) as Dictionary {
        return {
            "state" => state,
            "display_state" => displayValue,
            "unit" => "°C",
            "device_class" => "temperature",
            "area_id" => areaId,
            "name" => "Café Thermomètre",
            "available" => true
        };
    }
}

(:test)
function nonNumericSensorValueIsAbsentRatherThanZero(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseSensors(HaPayloadTest.sensorsPayload({
        "sensor.broken" => HaPayloadTest.reading(null, "unavailable", "area.kitchen"),
        "sensor.warm" => HaPayloadTest.reading(21.5, "21.5 °C", "area.kitchen")
    }));

    Test.assert((parsed.get("sensor.broken") as SensorModel).value == null);
    Test.assertEqual((parsed.get("sensor.warm") as SensorModel).value as Float, 21.5);
    return true;
}

(:test)
function sensorWithoutDisplayValueIsAbsent(logger as Test.Logger) as Boolean {
    // The display value is the row's only text, so an entry with none cannot be
    // rendered at all — absent beats present with nulls.
    var parsed = HaPayload.parseSensors(HaPayloadTest.sensorsPayload({
        "sensor.mute" => HaPayloadTest.reading(21.5, null, "area.kitchen")
    }));

    Test.assert(parsed.get("sensor.mute") == null);
    return true;
}

(:test)
function unnamedAreaAndFloorSurviveWithNullNames(logger as Test.Logger) as Boolean {
    // A naming gap costs a label, not a room: dropping the entry would lose every
    // entity in it.
    var payload = {
        "areas" => { "area.nameless" => { "name" => null } },
        "floors" => { "floor.nameless" => { "name" => null, "order" => 0, "areas" => ["area.nameless"] } }
    };
    var areas = HaPayload.parseAreas(payload);
    var floors = HaPayload.parseFloors(payload);

    Test.assert(areas.hasKey("area.nameless"));
    Test.assert((areas.get("area.nameless") as AreaModel).name == null);
    Test.assertEqual(floors.size(), 1);
    Test.assert(floors[0].name == null);
    Test.assertEqual(floors[0].id, "floor.nameless");
    return true;
}

(:test)
function floorsAreOrderedAsHomeAssistantReportedThem(logger as Test.Logger) as Boolean {
    // Dictionary key order is hash order, so only the reported `order` can say
    // which floor comes first.
    var floors = HaPayload.parseFloors({
        "floors" => {
            "floor.attic" => { "name" => "Attic", "order" => 2, "areas" => [] as Array<String> },
            "floor.cellar" => { "name" => "Cellar", "order" => 0, "areas" => [] as Array<String> },
            "floor.ground" => { "name" => "Rez-de-chaussée", "order" => 1, "areas" => [] as Array<String> }
        }
    });

    Test.assertEqual(floors.size(), 3);
    Test.assertEqual(floors[0].id, "floor.cellar");
    Test.assertEqual(floors[1].name as String, "Rez-de-chaussée");
    Test.assertEqual(floors[2].id, "floor.attic");
    return true;
}

(:test)
function memberIdsArePresentOnGroupsOnly(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.group" => { "state" => false, "area_id" => "area.a",
            "memberIds" => ["light.one", "light.two"] },
        "light.plain" => { "state" => false, "area_id" => "area.a" }
    }));

    Test.assertEqual(((parsed.get("light.group") as LightModel).memberIds as Array<String>).size(), 2);
    Test.assert((parsed.get("light.plain") as LightModel).memberIds == null);
    return true;
}

(:test)
function eitherArrivalOrderOfTheTargetsProducesTheSameState(logger as Test.Logger) as Boolean {
    // The structure target and the entity targets are separate requests, so
    // neither may depend on the other having landed.
    var structure = { "zone" => "Kotitalo", "areas" => { "area.kitchen" => { "name" => "Küche" } } };
    var lights = HaPayloadTest.lightsPayload({
        "light.kitchen" => { "state" => true, "name" => "Küchenlicht", "area_id" => "area.kitchen" }
    });

    var structureFirst = new HaState();
    HaPayloadTest.applyStructure(structureFirst, structure);
    structureFirst.setLights(HaPayload.parseLights(lights));

    var lightsFirst = new HaState();
    lightsFirst.setLights(HaPayload.parseLights(lights));
    HaPayloadTest.applyStructure(lightsFirst, structure);

    Test.assertEqual(structureFirst.getZone() as String, lightsFirst.getZone() as String);
    Test.assertEqual((structureFirst.getArea("area.kitchen") as AreaModel).name as String,
                     (lightsFirst.getArea("area.kitchen") as AreaModel).name as String);
    Test.assertEqual(structureFirst.getLightIdsInArea("area.kitchen").size(),
                     lightsFirst.getLightIdsInArea("area.kitchen").size());
    Test.assertEqual(structureFirst.isOn("light.kitchen"), lightsFirst.isOn("light.kitchen"));
    return true;
}

(:test)
function unusableInputParsesToAnEmptyTargetRatherThanThrowing(logger as Test.Logger) as Boolean {
    // The webhook can hand back anything; an empty target keeps the watch running
    // where a throw would not.
    Test.assertEqual(HaPayload.parseLights(null).size(), 0);
    Test.assertEqual(HaPayload.parseSensors("not a payload").size(), 0);
    Test.assertEqual(HaPayload.parseAreas({ "areas" => "not a map" }).size(), 0);
    Test.assert(HaPayload.parseZone(null) == null);
    return true;
}
