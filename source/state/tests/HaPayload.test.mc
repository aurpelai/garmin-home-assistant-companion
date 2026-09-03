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

    function fansPayload(entries as Dictionary) as Dictionary {
        return { "fans" => entries };
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
function malformedAggregatePayloadsYieldEmptyRatherThanThrow(logger as Test.Logger) as Boolean {
    var junk = { "areas" => "garbage", "floors" => 7, "home" => ["nope"] };

    Test.assert(HaPayload.parseHomeLightSummary(junk) == null);
    Test.assertEqual(HaPayload.parseAverages(junk, "areas").size(), 0);
    Test.assertEqual(HaPayload.parseHomeAverages(junk).size(), 0);
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
    Test.assertEqual((lights.get("light.kitchen") as LightModel).domain, Domain.LIGHT);
    Test.assertEqual((sensors.get("sensor.warm") as SensorModel).id, "sensor.warm");
    return true;
}

(:test)
function aStateThatIsNotABooleanReadsAsOff(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.odd" => { "state" => "on", "area_id" => "area.a" }
    }));

    Test.assert(!(parsed.get("light.odd") as LightModel).state);
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
function aLightCarriesItsBrightnessPercentOrNone(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.lit" => { "state" => true, "area_id" => "area.a", "brightness" => 50 },
        "light.dark" => { "state" => false, "area_id" => "area.a", "brightness" => null },
        "light.mute" => { "state" => false, "area_id" => "area.a" }
    }));

    Test.assertEqual((parsed.get("light.lit") as LightModel).brightness as Number, 50);
    Test.assert((parsed.get("light.dark") as LightModel).brightness == null);
    Test.assert((parsed.get("light.mute") as LightModel).brightness == null);
    return true;
}

(:test)
function aLightCarriesItsColorTempRangeAndCapability(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseLights(HaPayloadTest.lightsPayload({
        "light.warm" => { "state" => true, "area_id" => "area.a", "color_temp_kelvin" => 3000,
            "min_color_temp_kelvin" => 2000, "max_color_temp_kelvin" => 6500, "supports_color_temp" => true },
        "light.plain" => { "state" => true, "area_id" => "area.a" }
    }));
    var warm = parsed.get("light.warm") as LightModel;
    var plain = parsed.get("light.plain") as LightModel;

    Test.assertEqual(warm.colorTempKelvin as Number, 3000);
    Test.assertEqual(warm.minColorTempKelvin as Number, 2000);
    Test.assertEqual(warm.maxColorTempKelvin as Number, 6500);
    Test.assert(warm.supportsColorTemp);
    Test.assert(plain.colorTempKelvin == null);
    Test.assert(!plain.supportsColorTemp);
    return true;
}

(:test)
function aFanParsesLikeALightPlusItsSpeed(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseFans(HaPayloadTest.fansPayload({
        "fan.ceiling" => { "state" => true, "name" => "Deckenventilator", "area_id" => "area.kitchen",
            "available" => false, "speed" => 66, "oscillating" => true,
            "supports_speed" => true, "supports_oscillation" => true },
        "fan.group" => { "state" => false, "area_id" => "area.a", "memberIds" => ["fan.one", "fan.two"] }
    }));
    var fan = parsed.get("fan.ceiling") as FanModel;

    Test.assertEqual(fan.id, "fan.ceiling");
    Test.assertEqual(fan.domain, Domain.FAN);
    Test.assert(fan.state);
    Test.assertEqual(fan.name, "Deckenventilator");
    Test.assertEqual(fan.areaId as String, "area.kitchen");
    Test.assert(!fan.available);
    Test.assertEqual(fan.speed as Number, 66);
    Test.assert(fan.resolveOscillation() == true);
    Test.assert(fan.supportsSpeed);
    Test.assert(fan.supportsOscillation);
    Test.assert(fan.memberIds == null);
    Test.assertEqual(((parsed.get("fan.group") as FanModel).memberIds as Array<String>).size(), 2);
    return true;
}

(:test)
function anOffFanKeepsTheSpeedHomeAssistantStillReports(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseFans(HaPayloadTest.fansPayload({
        "fan.idle" => { "state" => false, "area_id" => "area.a", "speed" => 10 }
    }));

    Test.assertEqual((parsed.get("fan.idle") as FanModel).speed as Number, 10);
    return true;
}

(:test)
function aFanWithNoSpeedIsStillPresent(logger as Test.Logger) as Boolean {
    var parsed = HaPayload.parseFans(HaPayloadTest.fansPayload({
        "fan.absent" => { "state" => true, "area_id" => "area.a" },
        "fan.null" => { "state" => true, "area_id" => "area.a", "speed" => null }
    }));

    Test.assertEqual(parsed.size(), 2);
    Test.assert((parsed.get("fan.absent") as FanModel).speed == null);
    Test.assert((parsed.get("fan.null") as FanModel).speed == null);
    return true;
}

(:test)
function unusableInputParsesToAnEmptyTargetRatherThanThrowing(logger as Test.Logger) as Boolean {
    Test.assertEqual(HaPayload.parseLights(null).size(), 0);
    Test.assertEqual(HaPayload.parseFans({ "fans" => "not a map" }).size(), 0);
    Test.assertEqual(HaPayload.parseSensors("not a payload").size(), 0);
    Test.assertEqual(HaPayload.parseAreas({ "areas" => "not a map" }).size(), 0);
    Test.assert(HaPayload.parseZone(null) == null);
    return true;
}
