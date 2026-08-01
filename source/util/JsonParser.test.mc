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
function jsonRejectsTrailingContent(logger as Test.Logger) as Boolean {
    Test.assert(JsonParser.parse("{} extra") == null);
    return true;
}

// Escapes appear as HA's `| tojson` delivers them, so the fixture exercises the
// real wire shape end to end into HomeState.
(:test)
function jsonFeedsHomeStateEndToEnd(logger as Test.Logger) as Boolean {
    var payload = "{\"areas\": {\"Bedroom\": [\"light.bedroom_lights\"]}, " +
        "\"sensors\": {\"Bedroom\": [\"sensor.bedroom_temperature\"]}, " +
        "\"states\": {\"light.bedroom_lights\": false}, " +
        "\"available\": {\"light.bedroom_lights\": true, \"sensor.bedroom_temperature\": true}, " +
        "\"names\": {\"light.bedroom_lights\": \"Bedroom Lights\", \"sensor.bedroom_temperature\": \"Temperature\"}, " +
        "\"groups\": {\"light.bedroom_lights\": 3}, " +
        "\"readings\": {\"sensor.bedroom_temperature\": {\"value\": 24.2, \"display\": \"24.2 \\u00b0C\", \"unit\": \"\\u00b0C\"}}, " +
        "\"kinds\": {\"sensor.bedroom_temperature\": \"temperature\"}, " +
        "\"floors\": [{\"name\": \"Apartment\", \"areas\": [\"Bedroom\"]}]}";

    var parsed = JsonParser.parse(payload);
    var home = HomeState.fromTemplateData(parsed as Dictionary or String or Null);

    Test.assert(!home.isEmpty());
    Test.assertEqual(home.getName("light.bedroom_lights"), "Bedroom Lights");
    Test.assertEqual(home.isOn("light.bedroom_lights"), false);
    Test.assertEqual(home.isGroup("light.bedroom_lights"), true);
    Test.assertEqual(home.getMemberCount("light.bedroom_lights"), 3);
    Test.assertEqual(home.getReading("sensor.bedroom_temperature") as String, "24.2 °C");
    Test.assertEqual(home.getKind("sensor.bedroom_temperature") as String, "temperature");
    return true;
}
