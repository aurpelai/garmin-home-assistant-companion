import Toybox.Lang;
import Toybox.Test;

// Reports a just-completed refresh, which is what keeps a reveal from fetching
// and leaves the current-view bookkeeping as the only thing under test.
(:test)
class FreshCoordinatorClient extends HaClient {

    function initialize() {
        HaClient.initialize();
    }

    function msSinceLastRefresh() as Number or Null {
        return 0;
    }
}

(:test)
class StubScreen {

    function isObsolete(haState as HaState) as Boolean {
        return false;
    }

    function rebuild(haState as HaState) as Void {
    }
}

(:test)
function aStaleHideDoesNotClearAViewAlreadyReplacedAsCurrent(logger as Test.Logger) as Boolean {
    var coordinator = new Coordinator(new FreshCoordinatorClient());
    var departing = new StubScreen();
    var arriving = new StubScreen();

    coordinator.onViewShown(departing);
    coordinator.onViewShown(arriving);

    // A stale hide arriving after arriving already took over must not clear
    // it: the clear only applies if the current-view fact still points at
    // the view that is hiding.
    coordinator.onViewHidden(departing);
    Test.assert(coordinator.currentView() == arriving);

    coordinator.onViewHidden(arriving);
    Test.assert(coordinator.currentView() == null);
    return true;
}
