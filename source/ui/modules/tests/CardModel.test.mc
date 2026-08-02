import Toybox.Lang;
import Toybox.Test;

// Exercises the card model's pure session -> card-dictionary functions:
// sequence construction, light/sensor summaries. Mirrors EntityMenuTest's
// stateOf/sessionOf helper style.

(:test)
module CardModelTest {

    function stateOf(payload as Dictionary) as HomeState {
        return HomeState.fromTemplateData(payload);
    }

    function sessionOf(payload as Dictionary) as HomeSession {
        return new HomeSession(new HaClient(), stateOf(payload));
    }
}

(:test)
function sequenceIsFloorCardThenItsAreaCardsThenNextFloor(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"], "Bedroom" => ["light.bedroom"] },
        "states" => {},
        "floors" => [
            { "name" => "Ground Floor", "areas" => ["Kitchen"] },
            { "name" => "Upstairs", "areas" => ["Bedroom"] }
        ]
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards.size(), 4);
    Test.assertEqual(cards[0].get(:type) as Symbol, :floor);
    Test.assertEqual(cards[0].get(:name) as String, "Ground Floor");
    Test.assertEqual(cards[1].get(:type) as Symbol, :area);
    Test.assertEqual(cards[1].get(:name) as String, "Kitchen");
    Test.assertEqual(cards[2].get(:type) as Symbol, :floor);
    Test.assertEqual(cards[2].get(:name) as String, "Upstairs");
    Test.assertEqual(cards[3].get(:type) as Symbol, :area);
    Test.assertEqual(cards[3].get(:name) as String, "Bedroom");
    return true;
}

(:test)
function trailingUnflooredAreasFollowAllFloors(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"], "Garage" => ["light.garage"] },
        "states" => {},
        "floors" => [
            { "name" => "Ground Floor", "areas" => ["Kitchen"] }
        ]
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards.size(), 3);
    Test.assertEqual(cards[0].get(:name) as String, "Ground Floor");
    Test.assertEqual(cards[1].get(:name) as String, "Kitchen");
    // The trailing unfloored area card carries no preceding floor card.
    Test.assertEqual(cards[2].get(:type) as Symbol, :area);
    Test.assertEqual(cards[2].get(:name) as String, "Garage");
    return true;
}

(:test)
function noFloorsYieldsOnlyAreaCards(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"], "Garage" => ["light.garage"] },
        "states" => {}
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards.size(), 2);
    Test.assertEqual(cards[0].get(:type) as Symbol, :area);
    Test.assertEqual(cards[1].get(:type) as Symbol, :area);
    return true;
}

(:test)
function areaCardsAreSelectableFloorCardsAreNot(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"] },
        "states" => {},
        "floors" => [{ "name" => "Ground Floor", "areas" => ["Kitchen"] }]
    });
    var cards = CardModel.buildCards(session);

    Test.assert(!(cards[0].get(:selectable) as Boolean));
    Test.assert(cards[1].get(:selectable) as Boolean);
    return true;
}

(:test)
function buildAreaLightSummaryCountsOnAndAvailableLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.a", "light.b", "light.c"] },
        "states" => { "light.a" => true, "light.b" => false, "light.c" => true }
    });
    var summary = CardModel.buildAreaLightSummary(session, "Room") as Dictionary;

    Test.assertEqual(summary.get(:on) as Number, 2);
    Test.assertEqual(summary.get(:available) as Number, 3);
    Test.assertEqual(summary.get(:unavailable) as Number, 0);
    return true;
}

(:test)
function buildAreaLightSummaryCountsUnavailableSeparatelyAndNotAsOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.a", "light.b", "light.c"] },
        "states" => { "light.a" => true, "light.b" => false, "light.c" => true },
        "available" => { "light.c" => false }
    });
    var summary = CardModel.buildAreaLightSummary(session, "Room") as Dictionary;

    Test.assertEqual(summary.get(:on) as Number, 1);
    Test.assertEqual(summary.get(:available) as Number, 2);
    Test.assertEqual(summary.get(:unavailable) as Number, 1);
    return true;
}

(:test)
function buildAreaLightSummaryExcludesTheGroupEntity(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.room_lights", "light.a", "light.b"] },
        "states" => { "light.room_lights" => true, "light.a" => true, "light.b" => false },
        "groups" => { "light.room_lights" => 2 }
    });
    var summary = CardModel.buildAreaLightSummary(session, "Room") as Dictionary;

    Test.assertEqual(summary.get(:on) as Number, 1);
    Test.assertEqual(summary.get(:available) as Number, 2);
    Test.assertEqual(summary.get(:unavailable) as Number, 0);
    return true;
}

(:test)
function buildAreaLightSummaryIsNullForASensorOnlyArea(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Attic" => [] as Array<String> },
        "sensors" => { "Attic" => ["sensor.attic_temp"] },
        "kinds" => { "sensor.attic_temp" => "temperature" },
        "readings" => { "sensor.attic_temp" => "18.0 °C" },
        "states" => {}
    });

    Test.assert(CardModel.buildAreaLightSummary(session, "Attic") == null);
    return true;
}

(:test)
function buildAreaSensorSummaryShowsFirstOfEachKind(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => [] as Array<String> },
        "sensors" => { "Room" => ["sensor.temp1", "sensor.temp2", "sensor.hum1"] },
        "states" => {},
        "kinds" => {
            "sensor.temp1" => "temperature", "sensor.temp2" => "temperature",
            "sensor.hum1" => "humidity"
        },
        "readings" => {
            "sensor.temp1" => { "value" => 21.5, "display" => "21.5 °C", "unit" => "°C" },
            "sensor.temp2" => { "value" => 23.0, "display" => "23.0 °C", "unit" => "°C" },
            "sensor.hum1" => { "value" => 40.0, "display" => "40 %", "unit" => "%" }
        }
    });
    var summary = CardModel.buildAreaSensorSummary(session, "Room");

    Test.assertEqual(summary.size(), 2);
    Test.assertEqual(summary[0].get(:kind) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "21.5 °C");
    Test.assertEqual(summary[1].get(:kind) as String, "humidity");
    Test.assertEqual(summary[1].get(:reading) as String, "40 %");
    return true;
}

(:test)
function buildAreaSensorSummaryFallsBackWhenFirstOfKindHasNoReading(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => [] as Array<String> },
        "sensors" => { "Room" => ["sensor.temp1", "sensor.temp2"] },
        "states" => {},
        "kinds" => { "sensor.temp1" => "temperature", "sensor.temp2" => "temperature" },
        "readings" => {
            "sensor.temp2" => { "value" => 23.0, "display" => "23.0 °C", "unit" => "°C" }
        }
    });
    var summary = CardModel.buildAreaSensorSummary(session, "Room");

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:kind) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "23.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryAveragesAcrossAreas(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String>, "Bedroom" => [] as Array<String> },
        "sensors" => { "Kitchen" => ["sensor.k_temp"], "Bedroom" => ["sensor.b_temp"] },
        "states" => {},
        "kinds" => { "sensor.k_temp" => "temperature", "sensor.b_temp" => "temperature" },
        "readings" => {
            "sensor.k_temp" => { "value" => 19.0, "display" => "19.0 °C", "unit" => "°C" },
            "sensor.b_temp" => { "value" => 23.0, "display" => "23.0 °C", "unit" => "°C" },
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Bedroom", "Kitchen"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:kind) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "21.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryMeanRoundsToOneDecimal(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String>, "Bedroom" => [] as Array<String>, "Study" => [] as Array<String> },
        "sensors" => {
            "Kitchen" => ["sensor.k_temp"], "Bedroom" => ["sensor.b_temp"], "Study" => ["sensor.s_temp"]
        },
        "states" => {},
        "kinds" => {
            "sensor.k_temp" => "temperature", "sensor.b_temp" => "temperature", "sensor.s_temp" => "temperature"
        },
        "readings" => {
            "sensor.k_temp" => { "value" => 20.0, "display" => "20.0 °C", "unit" => "°C" },
            "sensor.b_temp" => { "value" => 21.0, "display" => "21.0 °C", "unit" => "°C" },
            "sensor.s_temp" => { "value" => 22.0, "display" => "22.0 °C", "unit" => "°C" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Kitchen", "Bedroom", "Study"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:reading) as String, "21.0 °C");
    return true;
}
