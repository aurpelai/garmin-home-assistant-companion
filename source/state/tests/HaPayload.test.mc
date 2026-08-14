import Toybox.Lang;
import Toybox.Test;

(:test)
module HaPayloadTest {

    function lightsPayload(entries as Dictionary) as Dictionary {
        return { "lights" => entries };
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

    Test.assert((parsed.sensors.get("sensor.broken") as SensorModel).value == null);
    Test.assertEqual((parsed.sensors.get("sensor.warm") as SensorModel).value as Float, 21.5);
    return true;
}

(:test)
function sensorWithoutDisplayValueIsAbsent(logger as Test.Logger) as Boolean {
    // The display value is the row's only text, so an entry with none cannot be
    // rendered at all — absent beats present with nulls.
    var parsed = HaPayload.parseSensors(HaPayloadTest.sensorsPayload({
        "sensor.mute" => HaPayloadTest.reading(21.5, null, "area.kitchen")
    }));

    Test.assert(parsed.sensors.get("sensor.mute") == null);
    Test.assert(parsed.sensorIdsByArea.get("area.kitchen") == null);
    return true;
}

(:test)
function unnamedAreaAndFloorSurviveWithNullNames(logger as Test.Logger) as Boolean {
    // A naming gap costs a label, not a room: dropping the entry would lose every
    // entity in it.
    var parsed = HaPayload.parseStructure({
        "areas" => { "area.nameless" => { "name" => null } },
        "floors" => { "floor.nameless" => { "name" => null, "order" => 0, "areas" => ["area.nameless"] } }
    });

    Test.assert(parsed.areas.hasKey("area.nameless"));
    Test.assert((parsed.areas.get("area.nameless") as AreaModel).name == null);
    Test.assertEqual(parsed.floors.size(), 1);
    Test.assert(parsed.floors[0].name == null);
    Test.assertEqual(parsed.floors[0].id, "floor.nameless");
    return true;
}

(:test)
function areaMembershipIsGroupedFromEachEntitysOwnAreaId(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.kitchen_ceiling" => { "state" => true, "area_id" => "area.kitchen" },
        "light.kitchen_counter" => { "state" => false, "area_id" => "area.kitchen" },
        "light.bedroom" => { "state" => false, "area_id" => "area.bedroom" }
    }));

    Test.assertEqual((parsed.lightIdsByArea.get("area.kitchen") as Array<String>).size(), 2);
    Test.assertEqual((parsed.lightIdsByArea.get("area.bedroom") as Array<String>).size(), 1);
    Test.assertEqual((parsed.lightIdsByArea.get("area.bedroom") as Array<String>)[0], "light.bedroom");
    return true;
}

(:test)
function floorsAreOrderedAsHomeAssistantReportedThem(logger as Test.Logger) as Boolean {
    // Dictionary key order is hash order, so only the reported `order` can say
    // which floor comes first.
    var parsed = HaPayload.parseStructure({
        "floors" => {
            "floor.attic" => { "name" => "Attic", "order" => 2, "areas" => [] as Array<String> },
            "floor.cellar" => { "name" => "Cellar", "order" => 0, "areas" => [] as Array<String> },
            "floor.ground" => { "name" => "Rez-de-chaussée", "order" => 1, "areas" => [] as Array<String> }
        }
    });

    Test.assertEqual(parsed.floors.size(), 3);
    Test.assertEqual(parsed.floors[0].id, "floor.cellar");
    Test.assertEqual(parsed.floors[1].name as String, "Rez-de-chaussée");
    Test.assertEqual(parsed.floors[2].id, "floor.attic");
    return true;
}

(:test)
function memberIdsArePresentOnGroupsOnly(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.group" => { "state" => false, "area_id" => "area.a",
            "memberIds" => ["light.one", "light.two"] },
        "light.plain" => { "state" => false, "area_id" => "area.a" }
    }));

    Test.assertEqual(((parsed.lights.get("light.group") as LightModel).memberIds as Array<String>).size(), 2);
    Test.assert((parsed.lights.get("light.plain") as LightModel).memberIds == null);
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
    structureFirst.setStructure(HaPayload.parseStructure(structure));
    structureFirst.setLights(HaPayload.parseLights(lights));

    var lightsFirst = new HaState();
    lightsFirst.setLights(HaPayload.parseLights(lights));
    lightsFirst.setStructure(HaPayload.parseStructure(structure));

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
    Test.assertEqual(HaPayload.parseLights(null).lights.size(), 0);
    Test.assertEqual(HaPayload.parseSensors("not a payload").sensors.size(), 0);
    Test.assertEqual(HaPayload.parseStructure({ "areas" => "not a map" }).areas.size(), 0);
    Test.assert(HaPayload.parseStructure(null).zone == null);
    return true;
}
