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
function pagingMovesThroughTheSequenceAndStopsAtBothEnds(logger as Test.Logger) as Boolean {
    var session = CardLoopViewTest.sessionOf({
        "areas" => { "Kitchen" => ["light.kitchen"], "Hallway" => ["light.hallway"] },
        "states" => {},
        "floors" => [{ "name" => "Ground Floor", "areas" => ["Hallway", "Kitchen"] }]
    });
    var view = new CardLoopView(session);
    view.redraw();

    Test.assertEqual(view.cardCount(), 3);
    Test.assertEqual(view.currentIndex(), 0);

    view.showPrevious();
    Test.assertEqual(view.currentIndex(), 0);

    view.showNext();
    view.showNext();
    Test.assertEqual(view.currentIndex(), 2);

    view.showNext();
    Test.assertEqual(view.currentIndex(), 2);
    return true;
}
