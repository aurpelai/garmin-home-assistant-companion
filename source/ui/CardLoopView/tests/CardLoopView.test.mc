import Toybox.Lang;
import Toybox.Test;

// Exercises the card loop view's paging, over a session built from a grouped
// payload. Mirrors EntityMenuTest's stateOf/sessionOf helper style; card
// content and sequencing are covered by CardModelTest.

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

    view.redraw();
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
