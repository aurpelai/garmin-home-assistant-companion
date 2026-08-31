import Toybox.Lang;
import Toybox.Test;

(:test)
module CardLoopTest {

    function stateOf(structure as Dictionary, lights as Dictionary) as HaState {
        var haState = new HaState();

        haState.setZone(HaPayload.parseZone(structure));

        haState.setAreas(HaPayload.parseAreas(structure));

        haState.setFloors(HaPayload.parseFloors(structure));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));

        return haState;
    }

    function twoFloors() as HaState {
        return stateOf({
            "areas" => {
                "area.kitchen" => { "name" => "Kitchen" },
                "area.hallway" => { "name" => "Hallway" },
                "area.bedroom" => { "name" => "Bedroom" }
            },
            "floors" => {
                "floor.ground" => { "name" => "Ground", "order" => 0,
                    "areas" => ["area.hallway", "area.kitchen"] },
                "floor.upstairs" => { "name" => "Upstairs", "order" => 1,
                    "areas" => ["area.bedroom"] }
            }
        }, {
            "light.kitchen" => { "state" => true, "area_id" => "area.kitchen" },
            "light.hallway" => { "state" => true, "area_id" => "area.hallway" },
            "light.bedroom" => { "state" => true, "area_id" => "area.bedroom" }
        });
    }

    function loopOf(haState as HaState) as CardLoop {
        return new CardLoop(new Coordinator(new HaClient(new WebRequestSender())), CardLoopBuilder.build(haState));
    }

    function focusedId(loop as CardLoop) as String {
        return (loop.currentCard() as Card).id;
    }
}

(:test)
function pagingMovesThroughTheSequenceAndWrapsAtBothEnds(logger as Test.Logger) as Boolean {
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    Test.assertEqual(CardLoopTest.focusedId(loop), "floor.ground");

    loop.showPrevious();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.bedroom");

    loop.showNext();
    Test.assertEqual(CardLoopTest.focusedId(loop), "floor.ground");

    loop.showNext();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.hallway");
    return true;
}

(:test)
function aPushRestoresFocusByCardIdRatherThanByIndex(logger as Test.Logger) as Boolean {
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    loop.showPrevious();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.bedroom");

    loop.rebuild(CardLoopTest.stateOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen" },
            "area.bedroom" => { "name" => "Bedroom" }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen"] },
            "floor.upstairs" => { "name" => "Upstairs", "order" => 1, "areas" => ["area.bedroom"] }
        }
    }, {
        "light.kitchen" => { "state" => true, "area_id" => "area.kitchen" },
        "light.bedroom" => { "state" => true, "area_id" => "area.bedroom" }
    }));

    Test.assertEqual(CardLoopTest.focusedId(loop), "area.bedroom");
    return true;
}

(:test)
function aVanishedCardFallsBackToTheFloorItSatUnder(logger as Test.Logger) as Boolean {
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    loop.showPrevious();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.bedroom");

    loop.rebuild(CardLoopTest.stateOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen" },
            "area.attic" => { "name" => "Attic" }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen"] },
            "floor.upstairs" => { "name" => "Upstairs", "order" => 1, "areas" => ["area.attic"] }
        }
    }, {
        "light.kitchen" => { "state" => true, "area_id" => "area.kitchen" },
        "light.attic" => { "state" => true, "area_id" => "area.attic" }
    }));

    Test.assertEqual(CardLoopTest.focusedId(loop), "floor.upstairs");
    return true;
}

(:test)
function theCardLoopIsNeverObsolete(logger as Test.Logger) as Boolean {
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    Test.assert(!loop.isObsolete(new HaState()));
    return true;
}
