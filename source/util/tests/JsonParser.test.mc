import Toybox.Lang;
import Toybox.Test;

(:test)
function jsonParsesFlatObject(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"a\": 1, \"b\": true, \"c\": false, \"d\": null}") as Dictionary;

    Test.assertEqual(result.get("a") as Number, 1);
    Test.assertEqual(result.get("b") as Boolean, true);
    Test.assertEqual(result.get("c") as Boolean, false);
    Test.assert(result.get("d") == null);
    return true;
}

(:test)
function jsonParsesNestedStructure(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"areas\": {\"Bedroom\": [\"light.a\", \"light.b\"]}}") as Dictionary;

    var bedroom = (result.get("areas") as Dictionary).get("Bedroom") as Array;
    Test.assertEqual(bedroom.size(), 2);
    Test.assertEqual(bedroom[0] as String, "light.a");
    Test.assertEqual(bedroom[1] as String, "light.b");
    return true;
}

(:test)
function jsonParsesEmptyContainers(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"a\": {}, \"b\": []}") as Dictionary;

    Test.assert((result.get("a") as Dictionary).isEmpty());
    Test.assertEqual((result.get("b") as Array).size(), 0);
    return true;
}

(:test)
function jsonParsesIntegersAndFloats(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"i\": 42, \"neg\": -7, \"f\": 24.18, \"z\": 0.0}") as Dictionary;

    Test.assertEqual(result.get("i") as Number, 42);
    Test.assertEqual(result.get("neg") as Number, -7);
    Test.assert((result.get("f") as Float) > 24.17 && (result.get("f") as Float) < 24.19);
    Test.assert((result.get("z") as Float) == 0.0);
    return true;
}

// A \uXXXX escape for a non-ASCII glyph: the °C in a sensor reading's display
// string, which HA delivers as °C.
(:test)
function jsonDecodesUnicodeEscape(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"display\": \"24.2 \\u00b0C\"}") as Dictionary;

    Test.assertEqual(result.get("display") as String, "24.2 °C");
    return true;
}

// A raw (unescaped) multi-byte character in a string value, and one before a
// later string, to catch any index-unit mismatch between the scan and substring.
(:test)
function jsonParsesRawNonAscii(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"a\": \"Café\", \"b\": \"x\"}") as Dictionary;

    Test.assertEqual(result.get("a") as String, "Café");
    Test.assertEqual(result.get("b") as String, "x");
    return true;
}

(:test)
function jsonDecodesCommonEscapes(logger as Test.Logger) as Boolean {
    var result = JsonParser.parse("{\"q\": \"a\\\"b\", \"slash\": \"a\\\\b\", \"nl\": \"a\\nb\"}") as Dictionary;

    Test.assertEqual(result.get("q") as String, "a\"b");
    Test.assertEqual(result.get("slash") as String, "a\\b");
    Test.assertEqual(result.get("nl") as String, "a\nb");
    return true;
}

(:test)
function jsonRejectsMalformedInput(logger as Test.Logger) as Boolean {
    Test.assert(JsonParser.parse("{\"a\": }") == null);
    Test.assert(JsonParser.parse("{\"a\": 1,}") == null);
    Test.assert(JsonParser.parse("[1, 2") == null);
    Test.assert(JsonParser.parse("{\"a\" 1}") == null);
    Test.assert(JsonParser.parse("garbage") == null);
    return true;
}

(:test)
function jsonRejectsMalformedNumbers(logger as Test.Logger) as Boolean {
    Test.assert(JsonParser.parse("[1.2.3]") == null);
    Test.assert(JsonParser.parse("[1e2e3]") == null);
    Test.assert(JsonParser.parse("[--5]") == null);
    Test.assert(JsonParser.parse("[1e+-2]") == null);
    return true;
}

(:test)
function jsonRejectsTrailingContent(logger as Test.Logger) as Boolean {
    Test.assert(JsonParser.parse("{} extra") == null);
    return true;
}

// Escapes appear as HA's `| tojson` delivers them, so the fixture exercises the
// real wire shape end to end into HaState.
(:test)
function jsonFeedsHaStateEndToEnd(logger as Test.Logger) as Boolean {
    var payload = "{\"lights\": {\"light.bedroom_lights\": {\"state\": false, " +
            "\"name\": \"Bedroom Lights\", \"area_id\": \"area.bedroom\", " +
            "\"available\": true, \"memberIds\": [\"light.a\", \"light.b\", \"light.c\"]}}}";

    var haState = new HaState();
    haState.setLights(HaPayload.parseLights(JsonParser.parse(payload)));

    var lights = haState.getLightsInArea("area.bedroom");
    Test.assertEqual(lights.size(), 1);
    Test.assertEqual(lights[0].id, "light.bedroom_lights");
    Test.assertEqual(lights[0].name, "Bedroom Lights");
    Test.assertEqual(lights[0].state, false);
    Test.assertEqual((lights[0].memberIds as Array<String>).size(), 3);
    return true;
}

// A raw (unescaped) multi-byte character surviving a full parse-into-state
// round trip, not just the bare JsonParser call above.
(:test)
function jsonFeedsHaStateEndToEndWithRawNonAscii(logger as Test.Logger) as Boolean {
    var structure = "{\"areas\": {\"area.kitchen\": {\"name\": \"Küche\"}}}";
    var sensors = "{\"sensors\": {\"sensor.temp\": {\"state\": 21.5, " +
            "\"friendly_state\": \"21.5 °C\", \"unit\": \"°C\", " +
            "\"device_class\": \"temperature\", \"area_id\": \"area.kitchen\", " +
            "\"name\": \"Café Sensor\", \"available\": true}}}";

    var haState = new HaState();
    HaPayloadTest.applyStructure(haState, JsonParser.parse(structure) as Dictionary);
    haState.setSensors(HaPayload.parseSensors(JsonParser.parse(sensors)));

    var sensor = haState.getSensorsInArea("area.kitchen")[0];
    Test.assertEqual((haState.getArea("area.kitchen") as AreaModel).name, "Küche");
    Test.assertEqual(sensor.id, "sensor.temp");
    Test.assertEqual(sensor.name, "Café Sensor");
    Test.assertEqual(sensor.friendlyState, "21.5 °C");
    Test.assertEqual(sensor.unit as String, "°C");
    return true;
}
