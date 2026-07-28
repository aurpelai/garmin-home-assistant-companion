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
function buildAreaLightSummaryCountsLightsOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.a", "light.b", "light.c"] },
        "states" => { "light.a" => true, "light.b" => false, "light.c" => true }
    });

    Test.assertEqual(CardModel.buildAreaLightSummary(session, "Room") as String, "2 lights on");
    return true;
}

(:test)
function buildAreaLightSummaryExcludesTheGroupEntity(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.room_lights", "light.a", "light.b"] },
        "states" => { "light.room_lights" => true, "light.a" => true, "light.b" => false },
        "groups" => { "light.room_lights" => 2 }
    });

    Test.assertEqual(CardModel.buildAreaLightSummary(session, "Room") as String, "1 light on");
    return true;
}

(:test)
function buildAreaLightSummaryIsSingularForOneLight(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.a", "light.b"] },
        "states" => { "light.a" => true, "light.b" => false }
    });

    Test.assertEqual(CardModel.buildAreaLightSummary(session, "Room") as String, "1 light on");
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
        "readings" => { "sensor.temp2" => { "value" => 23.0, "display" => "23.0 °C", "unit" => "°C" } }
    });
    var summary = CardModel.buildAreaSensorSummary(session, "Room");

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:kind) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "23.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryRangesAcrossAreas(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String>, "Bedroom" => [] as Array<String> },
        "sensors" => { "Kitchen" => ["sensor.k_temp"], "Bedroom" => ["sensor.b_temp"] },
        "states" => {},
        "kinds" => { "sensor.k_temp" => "temperature", "sensor.b_temp" => "temperature" },
        "readings" => {
            "sensor.k_temp" => { "value" => 19.0, "display" => "19.0 °C", "unit" => "°C" },
            "sensor.b_temp" => { "value" => 23.0, "display" => "23.0 °C", "unit" => "°C" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Kitchen", "Bedroom"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:kind) as String, "temperature");
    Test.assertEqual(summary[0].get(:range) as String, "19.0–23.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryCollapsesToSingleValueWhenEndsEqual(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String>, "Bedroom" => [] as Array<String> },
        "sensors" => { "Kitchen" => ["sensor.k_temp"], "Bedroom" => ["sensor.b_temp"] },
        "states" => {},
        "kinds" => { "sensor.k_temp" => "temperature", "sensor.b_temp" => "temperature" },
        "readings" => {
            "sensor.k_temp" => { "value" => 21.0, "display" => "21.0 °C", "unit" => "°C" },
            "sensor.b_temp" => { "value" => 21.0, "display" => "21.0 °C", "unit" => "°C" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Kitchen", "Bedroom"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:range) as String, "21.0");
    return true;
}

(:test)
function buildFloorSensorSummarySkipsUnparseableReadings(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String>, "Bedroom" => [] as Array<String> },
        "sensors" => { "Kitchen" => ["sensor.k_temp"], "Bedroom" => ["sensor.b_temp"] },
        "states" => {},
        "kinds" => { "sensor.k_temp" => "temperature", "sensor.b_temp" => "temperature" },
        "readings" => {
            "sensor.k_temp" => { "value" => null, "display" => "unavailable", "unit" => "" },
            "sensor.b_temp" => { "value" => 23.0, "display" => "23.0 °C", "unit" => "°C" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Kitchen", "Bedroom"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:range) as String, "23.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryOmitsKindWhenAllUnparseable(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String> },
        "sensors" => { "Kitchen" => ["sensor.k_temp"] },
        "states" => {},
        "kinds" => { "sensor.k_temp" => "temperature" },
        "readings" => { "sensor.k_temp" => { "value" => null, "display" => "unavailable", "unit" => "" } }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Kitchen"]);

    Test.assertEqual(summary.size(), 0);
    return true;
}
