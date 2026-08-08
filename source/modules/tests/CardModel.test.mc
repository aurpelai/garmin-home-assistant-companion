import Toybox.Lang;
import Toybox.Test;

// Exercises the card model's pure session -> card-dictionary functions:
// sequence construction, light/sensor summaries.

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
    // Upstairs is listed first but carries the higher :order, so a correct
    // sequence puts Ground first — insertion order alone would not.
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.bedroom"] }
        },
        "floors" => {
            "floor.upstairs" => { "name" => "Upstairs", "order" => 1, "areas" => ["area.bedroom"] },
            "floor.ground" => { "name" => "Ground Floor", "order" => 0, "areas" => ["area.kitchen"] }
        }
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
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] },
            "area.garage" => { "name" => "Garage", "lights" => ["light.garage"] }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground Floor", "areas" => ["area.kitchen"] }
        }
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
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] },
            "area.garage" => { "name" => "Garage", "lights" => ["light.garage"] }
        }
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards.size(), 2);
    Test.assertEqual(cards[0].get(:type) as Symbol, :area);
    Test.assertEqual(cards[1].get(:type) as Symbol, :area);
    return true;
}

(:test)
function areaCardsandFloorCardsAreSelectable(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] } },
        "floors" => { "floor.ground" => { "name" => "Ground Floor", "areas" => ["area.kitchen"] } }
    });
    var cards = CardModel.buildCards(session);

    Test.assert((cards[0].get(:selectable) as Boolean));
    Test.assert(cards[1].get(:selectable) as Boolean);
    return true;
}

(:test)
function floorCardIsSelectableWithIdAndLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] } },
        "floors" => { "floor_ground" => { "name" => "Ground Floor", "areas" => ["area.kitchen"] } }
    });
    var cards = CardModel.buildCards(session);

    Test.assertEqual(cards[0].get(:type) as Symbol, :floor);
    Test.assert(cards[0].get(:selectable) as Boolean);
    return true;
}

(:test)
function buildAreaLightSummaryCountsOnAndAvailableLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room",
            "lights" => ["light.a", "light.b", "light.c"] } },
        "lights" => {
            "light.a" => { "state" => true }, "light.b" => { "state" => false },
            "light.c" => { "state" => true }
        }
    });
    var summary = CardModel.buildAreaLightSummary(session, "area.room") as Dictionary;

    Test.assertEqual(summary.get(:on) as Number, 2);
    Test.assertEqual(summary.get(:available) as Number, 3);
    Test.assertEqual(summary.get(:unavailable) as Number, 0);
    return true;
}

(:test)
function buildAreaLightSummaryCountsUnavailableSeparatelyAndNotAsOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room",
            "lights" => ["light.a", "light.b", "light.c"] } },
        "lights" => {
            "light.a" => { "state" => true }, "light.b" => { "state" => false },
            "light.c" => { "state" => true, "available" => false }
        }
    });
    var summary = CardModel.buildAreaLightSummary(session, "area.room") as Dictionary;

    Test.assertEqual(summary.get(:on) as Number, 1);
    Test.assertEqual(summary.get(:available) as Number, 2);
    Test.assertEqual(summary.get(:unavailable) as Number, 1);
    return true;
}

(:test)
function buildAreaLightSummaryExcludesTheGroupEntity(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room",
            "lights" => ["light.room_lights", "light.a", "light.b"] } },
        "lights" => {
            "light.room_lights" => { "state" => true, "memberCount" => 2 },
            "light.a" => { "state" => true }, "light.b" => { "state" => false }
        }
    });
    var summary = CardModel.buildAreaLightSummary(session, "area.room") as Dictionary;

    Test.assertEqual(summary.get(:on) as Number, 1);
    Test.assertEqual(summary.get(:available) as Number, 2);
    Test.assertEqual(summary.get(:unavailable) as Number, 0);
    return true;
}

(:test)
function buildAreaLightSummaryIsNullForASensorOnlyArea(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.attic" => { "name" => "Attic", "sensors" => ["sensor.attic_temp"] } },
        "sensors" => { "sensor.attic_temp" => { "state" => 18.0, "display_state" => "18.0 °C",
            "device_class" => "temperature" } }
    });

    Test.assert(CardModel.buildAreaLightSummary(session, "area.attic") == null);
    return true;
}

(:test)
function floorLightSummaryReadsAllOnWhenEveryAvailableLightIsOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.a"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.b"] }
        },
        "lights" => { "light.a" => { "state" => true }, "light.b" => { "state" => true } }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.kitchen", "area.bedroom"]),
                     "All lights on");
    return true;
}

(:test)
function floorLightSummaryReadsSomeOnWhenOnlyPartAreOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.a"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.b"] }
        },
        "lights" => { "light.a" => { "state" => true }, "light.b" => { "state" => false } }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.kitchen", "area.bedroom"]),
                     "Some lights on");
    return true;
}

(:test)
function floorLightSummaryReadsAllOffWhenNoneAreOn(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.a"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.b"] }
        },
        "lights" => { "light.a" => { "state" => false }, "light.b" => { "state" => false } }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.kitchen", "area.bedroom"]),
                     "All lights off");
    return true;
}

(:test)
function floorLightSummaryReadsNoneWhenFloorHasNoLights(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.attic" => { "name" => "Attic" } }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.attic"]),
                     "No lights available");
    return true;
}

(:test)
function floorLightSummaryReadsNoneWhenEveryLightIsUnavailable(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.a"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.b"] }
        },
        "lights" => {
            "light.a" => { "state" => true, "available" => false },
            "light.b" => { "state" => false, "available" => false }
        }
    });

    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.kitchen", "area.bedroom"]),
                     "No lights available");
    return true;
}

(:test)
function floorLightSummaryJudgesAmongAvailableLightsOnly(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room", "lights" => ["light.a", "light.b"] } },
        "lights" => {
            "light.a" => { "state" => true },
            "light.b" => { "state" => false, "available" => false }
        }
    });

    // light.b is unavailable, so the only available light (a) is on -> all on.
    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.room"]),
                     "All lights on");
    return true;
}

(:test)
function floorLightSummaryExcludesGroupEntities(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room",
            "lights" => ["light.room_lights", "light.a", "light.b"] } },
        "lights" => {
            "light.room_lights" => { "state" => true, "memberCount" => 2 },
            "light.a" => { "state" => false }, "light.b" => { "state" => false }
        }
    });

    // The group reads on, but only its members count -> both members off.
    Test.assertEqual(CardModel.buildFloorLightSummary(session, ["area.room"]),
                     "All lights off");
    return true;
}

(:test)
function buildAreaSensorSummaryShowsFirstOfEachDeviceClass(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room",
            "sensors" => ["sensor.temp1", "sensor.temp2", "sensor.hum1"] } },
        "sensors" => {
            "sensor.temp1" => { "state" => 21.5, "display_state" => "21.5 °C", "unit" => "°C",
                "device_class" => "temperature" },
            "sensor.temp2" => { "state" => 23.0, "display_state" => "23.0 °C", "unit" => "°C",
                "device_class" => "temperature" },
            "sensor.hum1" => { "state" => 40.0, "display_state" => "40 %", "unit" => "%",
                "device_class" => "humidity" }
        }
    });
    var summary = CardModel.buildAreaSensorSummary(session, "area.room");

    Test.assertEqual(summary.size(), 2);
    Test.assertEqual(summary[0].get(:device_class) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "21.5 °C");
    Test.assertEqual(summary[1].get(:device_class) as String, "humidity");
    Test.assertEqual(summary[1].get(:reading) as String, "40 %");
    return true;
}

(:test)
function buildAreaSensorSummarySkipsASensorAbsentFromThePayload(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room", "sensors" => ["sensor.temp1", "sensor.temp2"] } },
        "sensors" => {
            "sensor.temp2" => { "state" => 23.0, "display_state" => "23.0 °C", "unit" => "°C",
                "device_class" => "temperature" }
        }
    });
    var summary = CardModel.buildAreaSensorSummary(session, "area.room");

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:device_class) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "23.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryAveragesAcrossAreas(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "sensors" => ["sensor.k_temp"] },
            "area.bedroom" => { "name" => "Bedroom", "sensors" => ["sensor.b_temp"] }
        },
        "sensors" => {
            "sensor.k_temp" => { "state" => 19.0, "display_state" => "19.0 °C", "unit" => "°C",
                "device_class" => "temperature" },
            "sensor.b_temp" => { "state" => 23.0, "display_state" => "23.0 °C", "unit" => "°C",
                "device_class" => "temperature" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["area.bedroom", "area.kitchen"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:device_class) as String, "temperature");
    Test.assertEqual(summary[0].get(:reading) as String, "21.0 °C");
    return true;
}

(:test)
function buildAreaSensorSummaryDropsADeviceClassWhoseOnlySensorIsUnavailable(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.kitchen" => { "name" => "Kitchen",
            "sensors" => ["sensor.k_temp", "sensor.k_humidity"] } },
        "sensors" => {
            "sensor.k_temp" => { "state" => 0.0, "display_state" => "unavailable", "unit" => "°C",
                "device_class" => "temperature", "available" => false },
            "sensor.k_humidity" => { "state" => 41.0, "display_state" => "41 %", "unit" => "%",
                "device_class" => "humidity" }
        }
    });
    var summary = CardModel.buildAreaSensorSummary(session, "area.kitchen");

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:device_class) as String, "humidity");
    Test.assertEqual(summary[0].get(:reading) as String, "41 %");
    return true;
}

(:test)
function buildFloorSensorSummaryMeanExcludesUnavailableSensors(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "sensors" => ["sensor.k_temp"] },
            "area.bedroom" => { "name" => "Bedroom", "sensors" => ["sensor.b_temp"] }
        },
        "sensors" => {
            // An unavailable sensor reports a zero reading, which would drag the
            // mean down if it were counted.
            "sensor.k_temp" => { "state" => 0.0, "display_state" => "unavailable", "unit" => "°C",
                "device_class" => "temperature", "available" => false },
            "sensor.b_temp" => { "state" => 22.0, "display_state" => "22.0 °C", "unit" => "°C",
                "device_class" => "temperature" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["area.kitchen", "area.bedroom"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:reading) as String, "22.0 °C");
    return true;
}

(:test)
function buildFloorSensorSummaryMeanTakesFewestDecimalsOfItsInputs(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "sensors" => ["sensor.k_temp"] },
            "area.bedroom" => { "name" => "Bedroom", "sensors" => ["sensor.b_temp"] }
        },
        "sensors" => {
            // 21.5 carries one decimal, 22 carries none — the mean 21.75 rounds
            // to the coarser input's zero decimals.
            "sensor.k_temp" => { "state" => 21.5, "display_state" => "21.5 °C", "unit" => "°C",
                "device_class" => "temperature" },
            "sensor.b_temp" => { "state" => 22.0, "display_state" => "22 °C", "unit" => "°C",
                "device_class" => "temperature" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["area.kitchen", "area.bedroom"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:reading) as String, "22 °C");
    return true;
}

(:test)
function buildFloorSensorSummarySingleSensorShowsHaDisplayVerbatim(logger as Test.Logger) as Boolean {
    var session = CardModelTest.sessionOf({
        "areas" => { "area.attic" => { "name" => "Attic", "sensors" => ["sensor.lux"] } },
        "sensors" => {
            // A lone reading is echoed as HA sent it — no averaging, no
            // reformatting that would fabricate a decimal HA never showed.
            "sensor.lux" => { "state" => 0.0, "display_state" => "0 lx", "unit" => "lx",
                "device_class" => "illuminance" }
        }
    });
    var summary = CardModel.buildFloorSensorSummary(session, ["area.attic"]);

    Test.assertEqual(summary.size(), 1);
    Test.assertEqual(summary[0].get(:reading) as String, "0 lx");
    return true;
}
