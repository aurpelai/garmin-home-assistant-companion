import Toybox.Lang;
import Toybox.Test;

(:test)
module HaPayloadTest {

    function lightsPayload(entries as Dictionary) as Dictionary {
        return { "lights" => entries };
    }

    function applyStructure(haState as HaState, payload as Dictionary) as Void {
        haState.setZone(HaPayload.parseZone(payload));
        haState.setAreas(HaPayload.parseAreas(payload));
        haState.setFloors(HaPayload.parseFloors(payload));
    }

    function sensorsPayload(entries as Dictionary) as Dictionary {
        return { "sensors" => entries };
    }

    function reading(friendlyState as Object or Null, areaId as String) as Dictionary {
        return {
            "friendly_state" => friendlyState,
            "device_class" => "temperature",
            "area_id" => areaId,
            "name" => "Café Thermomètre",
            "available" => true
        };
    }
}

(:test)
function sensorWithoutFriendlyStateIsAbsent(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseSensors(HaPayloadTest.sensorsPayload({
        "sensor.mute" => HaPayloadTest.reading(null, "area.kitchen")
    }));

    Test.assert(parsed.get("sensor.mute") == null);
    return true;
}

(:test)
function everyParsedModelCarriesTheIdItIsKeyedUnder(logger as Test.Logger) as Boolean {
    var structure = {
        "areas" => { "area.kitchen" => { "name" => "Küche" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen"] } }
    };
    var lights = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.kitchen" => { "state" => true, "name" => "Küchenlicht", "area_id" => "area.kitchen" }
    }));
    var sensors = HaPayload.parseSensors(HaPayloadTest.sensorsPayload({
        "sensor.warm" => HaPayloadTest.reading("21.5 °C", "area.kitchen")
    }));

    Test.assertEqual((HaPayload.parseAreas(structure).get("area.kitchen") as AreaModel).id, "area.kitchen");
    Test.assertEqual(HaPayload.parseFloors(structure)[0].id, "floor.g");
    Test.assertEqual((lights.get("light.kitchen") as LightModel).id, "light.kitchen");
    Test.assertEqual((sensors.get("sensor.warm") as SensorModel).id, "sensor.warm");
    return true;
}

(:test)
function parsedModelsCarryTheNamesHomeAssistantRequires(logger as Test.Logger) as Boolean {
    var structure = {
        "areas" => { "area.kitchen" => { "name" => "Küche" } },
        "floors" => { "floor.g" => { "name" => "Rez-de-chaussée", "order" => 0,
            "areas" => ["area.kitchen"] } }
    };

    Test.assertEqual((HaPayload.parseAreas(structure).get("area.kitchen") as AreaModel).name, "Küche");
    Test.assertEqual(HaPayload.parseFloors(structure)[0].name, "Rez-de-chaussée");
    return true;
}

(:test)
function floorsAreOrderedAsHomeAssistantReportedThem(logger as Test.Logger) as Boolean {
    var floors = HaPayload.parseFloors({
        "floors" => {
            "floor.attic" => { "name" => "Attic", "order" => 2, "areas" => [] as Array<String> },
            "floor.cellar" => { "name" => "Cellar", "order" => 0, "areas" => [] as Array<String> },
            "floor.ground" => { "name" => "Rez-de-chaussée", "order" => 1, "areas" => [] as Array<String> }
        }
    });

    Test.assertEqual(floors.size(), 3);
    Test.assertEqual(floors[0].id, "floor.cellar");
    Test.assertEqual(floors[1].name, "Rez-de-chaussée");
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
    Test.assertEqual((structureFirst.getArea("area.kitchen") as AreaModel).name,
                     (lightsFirst.getArea("area.kitchen") as AreaModel).name);
    Test.assertEqual(structureFirst.getLightsInArea("area.kitchen").size(),
                     lightsFirst.getLightsInArea("area.kitchen").size());
    Test.assertEqual(structureFirst.isOn("light.kitchen"), lightsFirst.isOn("light.kitchen"));
    return true;
}

(:test)
function unusableInputParsesToAnEmptyTargetRatherThanThrowing(logger as Test.Logger) as Boolean {
    Test.assertEqual(HaPayload.parseLights(null).size(), 0);
    Test.assertEqual(HaPayload.parseSensors("not a payload").size(), 0);
    Test.assertEqual(HaPayload.parseAreas({ "areas" => "not a map" }).size(), 0);
    Test.assert(HaPayload.parseZone(null) == null);
    return true;
}
