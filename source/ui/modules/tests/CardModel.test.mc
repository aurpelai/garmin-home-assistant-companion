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
function floorCardIsSelectableWithIdAndLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"] },
        "states" => {},
        "floors" => [{ "id" => "floor_ground", "name" => "Ground Floor", "areas" => ["Kitchen"] }]
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards[0].get(:type) as Symbol, :floor);
    Test.assert(cards[0].get(:selectable) as Boolean);
    return true;
}

(:test)
function floorCardIsInertWithoutAnId(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"] },
        "states" => {},
        "floors" => [{ "name" => "Ground Floor", "areas" => ["Kitchen"] }]
    });
    var cards = CardModel.buildCards(session);

    Test.assert(!(cards[0].get(:selectable) as Boolean));
    return true;
}

(:test)
function floorCardIsInertWhenItHasNoLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Attic" => [] as Array<String> },
        "sensors" => { "Attic" => ["sensor.attic_temp"] },
        "kinds" => { "sensor.attic_temp" => "temperature" },
        "readings" => { "sensor.attic_temp" => { "value" => 18.0, "display" => "18.0 °C", "unit" => "°C" } },
        "states" => {},
        "floors" => [{ "id" => "floor_top", "name" => "Top Floor", "areas" => ["Attic"] }]
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards[0].get(:type) as Symbol, :floor);
    Test.assert(!(cards[0].get(:selectable) as Boolean));
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
function floorLightSummaryReadsAllOnWhenEveryAvailableLightIsOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.a"], "Bedroom" => ["light.b"] },
        "states" => { "light.a" => true, "light.b" => true }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Kitchen", "Bedroom"]),
                     "All lights on");
    return true;
}

(:test)
function floorLightSummaryReadsSomeOnWhenOnlyPartAreOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.a"], "Bedroom" => ["light.b"] },
        "states" => { "light.a" => true, "light.b" => false }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Kitchen", "Bedroom"]),
                     "Some lights on");
    return true;
}

(:test)
function floorLightSummaryReadsAllOffWhenNoneAreOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.a"], "Bedroom" => ["light.b"] },
        "states" => { "light.a" => false, "light.b" => false }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Kitchen", "Bedroom"]),
                     "All lights off");
    return true;
}

(:test)
function floorLightSummaryReadsNoneWhenFloorHasNoLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Attic" => [] as Array<String> },
        "states" => {}
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Attic"]),
                     "No lights available");
    return true;
}

(:test)
function floorLightSummaryReadsNoneWhenEveryLightIsUnavailable(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => ["light.a"], "Bedroom" => ["light.b"] },
        "states" => { "light.a" => true, "light.b" => false },
        "available" => { "light.a" => false, "light.b" => false }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Kitchen", "Bedroom"]),
                     "No lights available");
    return true;
}

(:test)
function floorLightSummaryJudgesAmongAvailableLightsOnly(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.a", "light.b"] },
        "states" => { "light.a" => true, "light.b" => false },
        "available" => { "light.b" => false }
    });

    // light.b is unavailable, so the only available light (a) is on -> all on.
    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Room"]),
                     "All lights on");
    return true;
}

(:test)
function floorLightSummaryExcludesGroupEntities(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Room" => ["light.room_lights", "light.a", "light.b"] },
        "states" => { "light.room_lights" => true, "light.a" => false, "light.b" => false },
        "groups" => { "light.room_lights" => 2 }
    });

    // The group reads on, but only its members count -> both members off.
    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["Room"]),
                     "All lights off");
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
function buildFloorSensorSummaryMeanTakesFewestDecimalsOfItsInputs(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Kitchen" => [] as Array<String>, "Bedroom" => [] as Array<String> },
        "sensors" => { "Kitchen" => ["sensor.k_temp"], "Bedroom" => ["sensor.b_temp"] },
        "states" => {},
        "kinds" => { "sensor.k_temp" => "temperature", "sensor.b_temp" => "temperature" },
        "readings" => {
            // 21.5 carries one decimal, 22 carries none — the mean 21.75 rounds
            // to the coarser input's zero decimals.
            "sensor.k_temp" => { "value" => 21.5, "display" => "21.5 °C", "unit" => "°C" },
            "sensor.b_temp" => { "value" => 22.0, "display" => "22 °C", "unit" => "°C" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Kitchen", "Bedroom"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:reading) as String, "22 °C");
    return true;
}

(:test)
function buildFloorSensorSummarySingleSensorShowsHaDisplayVerbatim(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "Attic" => [] as Array<String> },
        "sensors" => { "Attic" => ["sensor.lux"] },
        "states" => {},
        "kinds" => { "sensor.lux" => "illuminance" },
        // A lone reading is echoed as HA sent it — no averaging, no reformatting
        // that would fabricate a decimal HA never showed.
        "readings" => { "sensor.lux" => { "value" => 0.0, "display" => "0 lx", "unit" => "lx" } }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["Attic"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:reading) as String, "0 lx");
    return true;
}
