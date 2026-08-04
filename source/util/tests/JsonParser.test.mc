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
// real wire shape end to end into HomeState.
(:test)
function jsonFeedsHomeStateEndToEnd(logger as Test.Logger) as Boolean {
    var payload = "{\"areas\": {\"area.bedroom\": {\"name\": \"Bedroom\", " +
            "\"lights\": [\"light.bedroom_lights\"], \"sensors\": [\"sensor.bedroom_temperature\"]}}, " +
        "\"lights\": {\"light.bedroom_lights\": {\"state\": false, \"name\": \"Bedroom Lights\", " +
            "\"available\": true, \"memberCount\": 3}}, " +
        "\"sensors\": {\"sensor.bedroom_temperature\": {\"state\": 24.2, " +
            "\"display_state\": \"24.2 \\u00b0C\", \"unit\": \"\\u00b0C\", " +
            "\"device_class\": \"temperature\", \"name\": \"Temperature\", \"available\": true}}, " +
        "\"floors\": {\"floor.apartment\": {\"name\": \"Apartment\", \"areas\": [\"area.bedroom\"]}}}";

    var parsed = JsonParser.parse(payload);
    var home = HomeState.fromTemplateData(parsed as Dictionary or String or Null);

    Test.assert(!home.isEmpty());
    Test.assertEqual(home.getName("light.bedroom_lights"), "Bedroom Lights");
    Test.assertEqual(home.isOn("light.bedroom_lights"), false);
    Test.assertEqual(home.isGroup("light.bedroom_lights"), true);
    Test.assertEqual(home.getMemberCount("light.bedroom_lights"), 3);
    Test.assertEqual(home.getReading("sensor.bedroom_temperature") as String, "24.2 °C");
    Test.assertEqual(home.getDeviceClass("sensor.bedroom_temperature") as String, "temperature");
    return true;
}

// A raw (unescaped) multi-byte character surviving a full parse-into-model
// round trip, not just the bare JsonParser call above.
(:test)
function jsonFeedsHomeStateEndToEndWithRawNonAscii(logger as Test.Logger) as Boolean {
    var payload = "{\"areas\": {\"area.kitchen\": {\"name\": \"Küche\", \"sensors\": [\"sensor.temp\"]}}, " +
        "\"sensors\": {\"sensor.temp\": {\"state\": 21.5, \"display_state\": \"21.5 °C\", " +
            "\"unit\": \"°C\", \"device_class\": \"temperature\", \"name\": \"Café Sensor\"}}}";

    var parsed = JsonParser.parse(payload);
    var home = HomeState.fromTemplateData(parsed as Dictionary or String or Null);

    Test.assertEqual(home.getAreaName("area.kitchen"), "Küche");
    Test.assertEqual(home.getName("sensor.temp"), "Café Sensor");
    Test.assertEqual(home.getReading("sensor.temp") as String, "21.5 °C");
    return true;
}

// The parse must not fail the whole payload just because one entity id present
// in an area's list has no corresponding lights-section entry.
(:test)
function jsonFeedsHomeStateEndToEndWithAStateLessEntityDropped(logger as Test.Logger) as Boolean {
    var payload = "{\"areas\": {\"area.hall\": {\"name\": \"Hall\", " +
            "\"lights\": [\"light.ok\", \"light.stateless\"]}}, " +
        "\"lights\": {\"light.ok\": {\"state\": true, \"name\": \"Ok\", \"available\": true}}}";

    var parsed = JsonParser.parse(payload);
    var home = HomeState.fromTemplateData(parsed as Dictionary or String or Null);

    Test.assert(!home.isEmpty());
    Test.assert(home.isOn("light.ok"));
    // Absent from "lights": isOn degrades to false, never throws.
    Test.assert(!home.isOn("light.stateless"));
    return true;
}
