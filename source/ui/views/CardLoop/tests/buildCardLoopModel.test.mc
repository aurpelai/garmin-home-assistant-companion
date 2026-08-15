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

    function temperature(display as String, value as Float or Null, areaId as String) as Dictionary {
        return { "state" => value, "display_state" => display, "unit" => "°C",
            "device_class" => "temperature", "area_id" => areaId, "available" => value != null };
    }

    function cardIds(model as CardLoopModel) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < model.cards.size(); index++) {
            ids.add(model.cards[index].id);
        }

        return ids;
    }

    // Empty rather than null on a miss: a card never carries a blank reading, so
    // an empty result is unambiguous and keeps the assertions comparing strings.
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
    // Upstairs is listed first but carries the higher order, so a correct
    // sequence puts Ground first — payload order alone would not. Within a
    // floor, areas sort by name rather than by the order the floor listed them.
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
        CardLoopModelTest.cardIds(buildCardLoopModel(haState)).toString(),
        ["floor.ground", "area.kitchen", "floor.upstairs", "area.attic", "area.bedroom", "area.garage"].toString());
    return true;
}

(:test)
function anEmptyHomeYieldsAModelWithNoCardsRatherThanNull(logger as Test.Logger) as Boolean {
    // The card loop's builder has no subject to look up, so it cannot report
    // absence the way the per-screen builders do: an empty home is a finding
    // for the caller to act on, not a missing model.
    var model = buildCardLoopModel(new HaState());

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
        // A dead light is still one of the area's bulbs, so it is counted — as
        // unavailable, which the card draws as an outline rather than a dot it
        // could claim is off.
        "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false },
        // The group entity would double-count its own members.
        "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.on", "light.off"] }
    }, {} as Dictionary);
    var lights = new LightTally();
    lights.addAll(haState, haState.getLightIdsInArea("area.room"));

    Test.assertEqual(lights.on, 1);
    Test.assertEqual(lights.available, 2);
    Test.assertEqual(lights.unavailable, 1);
    return true;
}

(:test)
function severalSensorsOfOneDeviceClassAverageWhateverTheScope(logger as Test.Logger) as Boolean {
    // No one sensor speaks for its scope, so picking one would put whichever the
    // walk reached first on the card. An area with two of a class averages them
    // exactly as a floor averages across its areas.
    var haState = CardLoopModelTest.stateOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen" },
            "area.bedroom" => { "name" => "Bedroom" }
        },
        "floors" => { "floor.ground" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kitchen", "area.bedroom"] } }
    }, {} as Dictionary, {
        "sensor.kitchen_near" => CardLoopModelTest.temperature("18.0 °C", 18.0, "area.kitchen"),
        "sensor.kitchen_far" => CardLoopModelTest.temperature("20.0 °C", 20.0, "area.kitchen"),
        "sensor.bedroom" => CardLoopModelTest.temperature("23.0 °C", 23.0, "area.bedroom")
    });
    var model = buildCardLoopModel(haState);

    Test.assertEqual(CardLoopModelTest.readingOf(model, "area.kitchen", "temperature"), "19.0 °C");
    Test.assertEqual(CardLoopModelTest.readingOf(model, "floor.ground", "temperature"), "20.3 °C");
    return true;
}

(:test)
function aLoneReadingIsEchoedAsHomeAssistantSentIt(logger as Test.Logger) as Boolean {
    // Echoed rather than recomposed from the value: Home Assistant's grouping
    // separator is formatting we cannot reproduce, so a lone reading must pass
    // through untouched instead of being rebuilt as "1024 lx".
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.attic" => { "name" => "Attic" } }
    }, {} as Dictionary, {
        "sensor.lux" => { "state" => 1024.0, "display_state" => "1,024 lx", "unit" => "lx",
            "device_class" => "illuminance", "area_id" => "area.attic", "available" => true }
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(buildCardLoopModel(haState), "area.attic", "illuminance"),
        "1,024 lx");
    return true;
}

(:test)
function aFloorMeanTakesTheFewestDecimalsItsInputsCarried(logger as Test.Logger) as Boolean {
    // A mean is no more precise than its coarsest input, so 21.5 with 22 reads
    // 22 rather than 21.75. The unit is stripped by value, not guessed at a
    // separator, so a non-ASCII unit does not confuse the measurement.
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.a" => { "name" => "A" }, "area.b" => { "name" => "B" } },
        "floors" => { "floor.g" => { "name" => "G", "order" => 0, "areas" => ["area.a", "area.b"] } }
    }, {} as Dictionary, {
        "sensor.a" => CardLoopModelTest.temperature("21.5 °C", 21.5, "area.a"),
        "sensor.b" => CardLoopModelTest.temperature("22 °C", 22.0, "area.b")
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(buildCardLoopModel(haState), "floor.g", "temperature"), "22 °C");
    return true;
}

(:test)
function aFloorMeanExcludesAnUnusableReadingRatherThanCountingItAsZero(logger as Test.Logger) as Boolean {
    // An unavailable sensor's state arrives as null, never a numeric zero:
    // averaged in, it would drag the floor's reading down by half.
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.a" => { "name" => "A" }, "area.b" => { "name" => "B" } },
        "floors" => { "floor.g" => { "name" => "G", "order" => 0, "areas" => ["area.a", "area.b"] } }
    }, {} as Dictionary, {
        "sensor.dead" => CardLoopModelTest.temperature("unavailable", null, "area.a"),
        "sensor.live" => CardLoopModelTest.temperature("21.5 °C", 21.5, "area.b")
    });

    Test.assertEqual(
        CardLoopModelTest.readingOf(buildCardLoopModel(haState), "floor.g", "temperature"), "21.5 °C");
    return true;
}

(:test)
function aDeviceClassWhoseOnlySensorIsUnusableIsAbsentRatherThanBlank(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {} as Dictionary, {
        "sensor.dead" => CardLoopModelTest.temperature("unavailable", null, "area.room"),
        "sensor.humid" => { "state" => 41.0, "display_state" => "41 %", "unit" => "%",
            "device_class" => "humidity", "area_id" => "area.room", "available" => true }
    });
    var model = buildCardLoopModel(haState);

    Test.assertEqual(model.cards[0].readings.size(), 1);
    Test.assertEqual(CardLoopModelTest.readingOf(model, "area.room", "humidity"), "41 %");
    return true;
}
