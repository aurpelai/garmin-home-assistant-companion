import Toybox.Lang;
import Toybox.Test;

// Drives the card loop's own push seam: a model in, the focused card out.
// Card content and sequencing are covered by the builder's tests.

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
        return new CardLoop(new Coordinator(new HaClient()), buildCardLoopModel(haState));
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
    // A push can arrive with no user action behind it, so the index means
    // nothing: only the id names the card the user was looking at.
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    loop.showPrevious();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.bedroom");

    // The ground floor loses an area, which shifts every later index down.
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
    // The floor id is captured before the model is replaced, because a vanished
    // area cannot be looked up afterwards to find which floor it belonged to.
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
function aVanishedCardAndFloorFallBackToTheFirstCard(logger as Test.Logger) as Boolean {
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    loop.showPrevious();
    Test.assertEqual(CardLoopTest.focusedId(loop), "area.bedroom");

    loop.rebuild(CardLoopTest.stateOf({
        "areas" => { "area.kitchen" => { "name" => "Kitchen" } },
        "floors" => {
            "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen"] }
        }
    }, {
        "light.kitchen" => { "state" => true, "area_id" => "area.kitchen" }
    }));

    Test.assertEqual(CardLoopTest.focusedId(loop), "floor.ground");
    return true;
}

(:test)
function theCardLoopNeverReportsItsSubjectGone(logger as Test.Logger) as Boolean {
    // It builds from the whole of HaState, so it is the one screen no deletion
    // can empty out from under — which is what makes it the fallback
    // destination for every other screen's subject vanishing.
    var loop = CardLoopTest.loopOf(CardLoopTest.twoFloors());

    Test.assert(loop.rebuild(new HaState()));
    return true;
}
