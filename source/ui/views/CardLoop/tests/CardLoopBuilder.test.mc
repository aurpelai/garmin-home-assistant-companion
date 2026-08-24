import Toybox.Lang;
import Toybox.Test;

(:test)
module CardLoopModelTest {

    function stateOf(structure as Dictionary, lights as Dictionary,
                     sensors as Dictionary) as HaState {
        var haState = new HaState();
        haState.setZone(HaPayload.parseZone(structure));
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }

    function light(state as Boolean, areaId as String) as Dictionary {
        return { "state" => state, "area_id" => areaId, "available" => true };
    }

    function temperature(display as String, precision as Number, value as Float or Null,
                         areaId as String) as Dictionary {
        return { "state" => value, "friendly_state" => display, "display_precision" => precision,
            "unit" => "°C", "device_class" => "temperature", "area_id" => areaId,
            "available" => value != null };
    }

    function cardIds(model as CardLoopModel) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < model.cards.size(); index++) {
            ids.add(model.cards[index].id);
        }

        return ids;
    }

    function readingOf(model as CardLoopModel, cardId as String, deviceClass as String) as String {
        for (var index = 0; index < model.cards.size(); index++) {
            var card = model.cards[index];
            if (!card.id.equals(cardId)) {
                continue;
            }

            for (var readingIndex = 0; readingIndex < card.readings.size(); readingIndex++) {
                if (card.readings[readingIndex].deviceClass.equals(deviceClass)) {
                    return card.readings[readingIndex].text;
                }
            }
        }

        return "";
    }
}

(:test)
function eachFloorHeadsItsOwnAreasAndUnflooredAreasTrailEveryFloor(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => {
            "area.bedroom" => { "name" => "Bedroom" },
            "area.kitchen" => { "name" => "Kitchen" },
            "area.attic" => { "name" => "Attic" },
            "area.garage" => { "name" => "Garage" }
        },
        "floors" => {
            "floor.upstairs" => { "name" => "Upstairs", "order" => 1, "areas" => ["area.bedroom", "area.attic"] },
            "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen"] }
        }
    }, {
        "light.bedroom" => CardLoopModelTest.light(false, "area.bedroom"),
        "light.kitchen" => CardLoopModelTest.light(false, "area.kitchen"),
        "light.attic" => CardLoopModelTest.light(false, "area.attic"),
        "light.garage" => CardLoopModelTest.light(false, "area.garage")
    }, {} as Dictionary);

    Test.assertEqual(
        CardLoopModelTest.cardIds(CardLoopBuilder.build(haState)).toString(),
        ["floor.ground", "area.kitchen", "floor.upstairs", "area.attic", "area.bedroom", "area.garage"].toString());
    return true;
}

(:test)
function anEmptyHomeYieldsAModelWithNoCardsRatherThanNull(logger as Test.Logger) as Boolean {
    var model = CardLoopBuilder.build(new HaState());

    Test.assertEqual(model.cards.size(), 0);
    return true;
}

(:test)
function anAreaCardTalliesPhysicalLightsAndSplitsThemByAvailability(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {
        "light.on" => CardLoopModelTest.light(true, "area.room"),
        "light.off" => CardLoopModelTest.light(false, "area.room"),
        "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false },
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.on", "light.off"] }
    }, {} as Dictionary);
    var lights = new LightTally();
    lights.addAll(haState.getLightsInArea("area.room"));

    Test.assertEqual(lights.on, 1);
    Test.assertEqual(lights.available, 2);
    Test.assertEqual(lights.unavailable, 1);
    return true;
}

(:test)
function severalSensorsOfOneDeviceClassAverageWhateverTheScope(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen" },
            "area.bedroom" => { "name" => "Bedroom" }
        },
        "floors" => { "floor.ground" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kitchen", "area.bedroom"] } }
    }, {} as Dictionary, {
        "sensor.kitchen_near" => CardLoopModelTest.temperature("18.0 °C", 1, 18.0, "area.kitchen"),
        "sensor.kitchen_far" => CardLoopModelTest.temperature("20.0 °C", 1, 20.0, "area.kitchen"),
        "sensor.bedroom" => CardLoopModelTest.temperature("23.0 °C", 1, 23.0, "area.bedroom")
    });
    var model = CardLoopBuilder.build(haState);

    Test.assertEqual(CardLoopModelTest.readingOf(model, "area.kitchen", "temperature"), "19.0 °C");
    Test.assertEqual(CardLoopModelTest.readingOf(model, "floor.ground", "temperature"), "20.3 °C");
    return true;
}

(:test)
function aLoneReadingIsEchoedAsHomeAssistantSentIt(logger as Test.Logger) as Boolean {
    // UNVERIFIED: Home Assistant's own formatting of a reading cannot be
    // reproduced on the watch, so a lone reading is echoed untouched.
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.attic" => { "name" => "Attic" } }
    }, {} as Dictionary, {
        "sensor.lux" => { "state" => 1024.0, "friendly_state" => "1,024 lx", "display_precision" => 0,
            "unit" => "lx", "device_class" => "illuminance", "area_id" => "area.attic", "available" => true }
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(CardLoopBuilder.build(haState), "area.attic", "illuminance"),
        "1,024 lx");
    return true;
}

(:test)
function aFloorMeanTakesTheFewestDecimalsItsInputsCarried(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.a" => { "name" => "A" }, "area.b" => { "name" => "B" } },
        "floors" => { "floor.g" => { "name" => "G", "order" => 0, "areas" => ["area.a", "area.b"] } }
    }, {} as Dictionary, {
        "sensor.a" => CardLoopModelTest.temperature("21.5 °C", 1, 21.5, "area.a"),
        "sensor.b" => CardLoopModelTest.temperature("22 °C", 0, 22.0, "area.b")
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(CardLoopBuilder.build(haState), "floor.g", "temperature"), "22 °C");
    return true;
}

(:test)
function aMeanOfMixedPrecisionMembersTakesTheFewestDecimals(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.a" => { "name" => "A" }, "area.b" => { "name" => "B" } },
        "floors" => { "floor.g" => { "name" => "G", "order" => 0, "areas" => ["area.a", "area.b"] } }
    }, {} as Dictionary, {
        "sensor.fine" => CardLoopModelTest.temperature("24.390 °C", 3, 24.39, "area.a"),
        "sensor.coarse" => CardLoopModelTest.temperature("24.4 °C", 1, 24.4, "area.b")
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(CardLoopBuilder.build(haState), "floor.g", "temperature"), "24.4 °C");
    return true;
}

(:test)
function aFloorMeanExcludesAnUnusableReadingRatherThanCountingItAsZero(logger as Test.Logger) as Boolean {
    // UNVERIFIED: an unavailable sensor's state arrives as null, never a zero.
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.a" => { "name" => "A" }, "area.b" => { "name" => "B" } },
        "floors" => { "floor.g" => { "name" => "G", "order" => 0, "areas" => ["area.a", "area.b"] } }
    }, {} as Dictionary, {
        "sensor.dead" => CardLoopModelTest.temperature("unavailable", 0, null, "area.a"),
        "sensor.live" => CardLoopModelTest.temperature("21.5 °C", 1, 21.5, "area.b")
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(CardLoopBuilder.build(haState), "floor.g", "temperature"), "21.5 °C");
    return true;
}

(:test)
function aDeviceClassWhoseOnlySensorIsUnusableIsAbsentRatherThanBlank(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {} as Dictionary, {
        "sensor.dead" => CardLoopModelTest.temperature("unavailable", 0, null, "area.room"),
        "sensor.humid" => { "state" => 41.0, "friendly_state" => "41 %", "display_precision" => 0, "unit" => "%",
            "device_class" => "humidity", "area_id" => "area.room", "available" => true }
    });
    var model = CardLoopBuilder.build(haState);

    Test.assertEqual(model.cards[0].readings.size(), 1);
    Test.assertEqual(CardLoopModelTest.readingOf(model, "area.room", "humidity"), "41 %");
    return true;
}

(:test)
function anAreaWithNoEntitiesGetsNoCardAndTakesItsEmptyFloorWithIt(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.stocked" => { "name" => "Stocked" }, "area.bare" => { "name" => "Bare" } },
        "floors" => { "floor.empty" => { "name" => "Empty", "order" => 0, "areas" => ["area.bare"] } }
    }, {
        "light.stocked" => CardLoopModelTest.light(false, "area.stocked")
    }, {} as Dictionary);

    Test.assertEqual(
        CardLoopModelTest.cardIds(CardLoopBuilder.build(haState)).toString(),
        ["area.stocked"].toString());
    return true;
}

(:test)
function anAreasEntitiesReachBothItsOwnCardAndItsFloorsAggregate(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => ["area.room"] } }
    }, {
        "light.room" => CardLoopModelTest.light(true, "area.room")
    }, {
        "sensor.room" => CardLoopModelTest.temperature("21.0 °C", 1, 21.0, "area.room")
    });
    var model = CardLoopBuilder.build(haState);

    Test.assertEqual(CardLoopModelTest.readingOf(model, "area.room", "temperature"), "21.0 °C");
    Test.assertEqual(CardLoopModelTest.readingOf(model, "floor.g", "temperature"), "21.0 °C");
    return true;
}

(:test)
function anAreaWhoseOnlyEntityIsUnavailableStillGetsACard(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {} as Dictionary, {
        "sensor.dead" => CardLoopModelTest.temperature("unavailable", 0, null, "area.room")
    });

    Test.assertEqual(
        CardLoopModelTest.cardIds(CardLoopBuilder.build(haState)).toString(),
        ["area.room"].toString());
    return true;
}
