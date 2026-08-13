import Toybox.Lang;
import Toybox.Test;

// Card content and sequencing are covered by CardModelTest.

(:test)
module CardLoopViewTest {

    function stateOf(payload as Dictionary) as HomeState {
        return HomeState.fromTemplateData(payload);
    }

    function sessionOf(payload as Dictionary) as HomeSession {
        return new HomeSession(new HaClient(), stateOf(payload));
    }
}

(:test)
function pagingMovesThroughTheSequenceAndWrapsAtBothEnds(logger as Test.Logger) as Boolean {
    var session = CardLoopViewTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] },
            "area.hallway" => { "name" => "Hallway", "lights" => ["light.hallway"] }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground Floor", "areas" => ["area.hallway", "area.kitchen"] }
        }
    });
    var view = new CardLoopView(session);

    view.draw();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Ground Floor");

    view.showPrevious();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Kitchen");

    view.showNext();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Ground Floor");

    view.showNext();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Hallway");

    view.showNext();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Kitchen");

    view.showNext();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Ground Floor");

    return true;
}

(:test)
function aRefreshThatDropsCardsLandsOnAPageThatStillExists(logger as Test.Logger) as Boolean {
    var session = CardLoopViewTest.sessionOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] },
            "area.hallway" => { "name" => "Hallway", "lights" => ["light.hallway"] },
            "area.bedroom" => { "name" => "Bedroom", "lights" => ["light.bedroom"] }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground Floor", "order" => 0, "areas" => ["area.hallway", "area.kitchen"] },
            "floor.upstairs" => { "name" => "Upstairs", "order" => 1, "areas" => ["area.bedroom"] }
        }
    });
    var view = new CardLoopView(session);

    view.draw();
    view.showPrevious();
    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Bedroom");

    session.applyState(CardLoopViewTest.stateOf({
        "areas" => {
            "area.kitchen" => { "name" => "Kitchen", "lights" => ["light.kitchen"] }
        },
        "floors" => {
            "floor.ground" => { "name" => "Ground Floor", "order" => 0, "areas" => ["area.kitchen"] }
        }
    }));
    view.draw();

    Test.assertEqual((view.getCurrentCard() as Dictionary).get(:name) as String, "Kitchen");

    return true;
}
