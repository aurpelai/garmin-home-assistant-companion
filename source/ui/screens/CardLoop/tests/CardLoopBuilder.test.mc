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
        haState.setToggleables(Domain.LIGHT, HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));
        return haState;
    }

    function light(state as Boolean, areaId as String) as Dictionary {
        return { "state" => state, "area_id" => areaId, "available" => true };
    }

    function sensor(deviceClass as String, areaId as String) as Dictionary {
        return { "friendly_state" => "n/a", "device_class" => deviceClass,
            "name" => deviceClass, "area_id" => areaId, "available" => true };
    }

    function cardIds(model as CardLoopModel) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < model.cards.size(); index++) {
            ids.add(model.cards[index].id);
        }

        return ids;
    }

    function cardOf(model as CardLoopModel, cardId as String) as Card or Null {
        for (var index = 0; index < model.cards.size(); index++) {
            if (model.cards[index].id.equals(cardId)) {
                return model.cards[index];
            }
        }

        return null;
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
function aCardShowsTheMeansHomeAssistantComputedForItsScope(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => ["area.room"] } }
    }, {} as Dictionary, {
        "sensor.room" => CardLoopModelTest.sensor("temperature", "area.room")
    });
    haState.setSensorAverages(
        { "area.room" => { "temperature" => "21.0 °C" } },
        { "floor.g" => { "temperature" => "21.0 °C" } });
    var model = CardLoopBuilder.build(haState);

    Test.assertEqual(CardLoopModelTest.readingOf(model, "area.room", "temperature"), "21.0 °C");
    Test.assertEqual(CardLoopModelTest.readingOf(model, "floor.g", "temperature"), "21.0 °C");
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
function anAreaWhoseOnlyEntityIsAFanGetsACardAndHeadsItsFloor(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => ["area.room"] } }
    }, {} as Dictionary, {} as Dictionary);
    haState.setToggleables(Domain.FAN, HaPayload.parseFans({ "fans" => {
        "fan.room" => { "state" => false, "area_id" => "area.room", "available" => true } } }));

    Test.assertEqual(
        CardLoopModelTest.cardIds(CardLoopBuilder.build(haState)).toString(),
        ["floor.g", "area.room"].toString());
    return true;
}

(:test)
function anOptimisticallyToggledLightMovesTheCardCountAndFloorSummary(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => ["area.room"] } }
    }, {
        "light.room" => CardLoopModelTest.light(false, "area.room")
    }, {} as Dictionary);
    haState.override("light.room", true);

    var model = CardLoopBuilder.build(haState);
    var area = CardLoopModelTest.cardOf(model, "area.room") as AreaCard;
    var floor = CardLoopModelTest.cardOf(model, "floor.g") as FloorCard;

    Test.assertEqual(area.lights.on, 1);
    Test.assertEqual(area.lights.available, 1);
    Test.assert((floor.lights as String).equals(LightSummary.ALL_ON));
    return true;
}

(:test)
function aGroupAndItsMembersMoveTheCountByPhysicalMembersOnly(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {
        "light.group" => { "state" => true, "area_id" => "area.room", "available" => true,
            "memberIds" => ["light.one", "light.two"] },
        "light.one" => CardLoopModelTest.light(true, "area.room"),
        "light.two" => CardLoopModelTest.light(false, "area.room")
    }, {} as Dictionary);

    var area = CardLoopModelTest.cardOf(CardLoopBuilder.build(haState), "area.room") as AreaCard;

    Test.assertEqual(area.lights.available, 2);
    Test.assertEqual(area.lights.on, 1);
    return true;
}

(:test)
function aFloorWithNoAvailableLightsYieldsNoSummary(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => ["area.room"] } }
    }, {
        "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
    }, {} as Dictionary);

    var floor = CardLoopModelTest.cardOf(CardLoopBuilder.build(haState), "floor.g") as FloorCard;

    Test.assert(floor.lights == null);
    return true;
}

(:test)
function anAreaWhoseOnlyEntityIsUnavailableStillGetsACard(logger as Test.Logger) as Boolean {
    var haState = CardLoopModelTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room" } }
    }, {} as Dictionary, {
        "sensor.dead" => { "friendly_state" => "Unavailable", "device_class" => "temperature",
            "name" => "Temperature", "area_id" => "area.room", "available" => false }
    });

    Test.assertEqual(
        CardLoopModelTest.cardIds(CardLoopBuilder.build(haState)).toString(),
        ["area.room"].toString());
    return true;
}
