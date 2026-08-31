import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The first screen, held until there is something to show. Reporting its
// subject as gone once entities arrive is what moves the user on, so the
// coordinator navigates and this view does not.
class LoadingView extends WatchUi.View {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        View.initialize();
        _coordinator = coordinator;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        WatchUi.pushView(
            new WatchUi.ProgressBar(
                WatchUi.loadResource(Rez.Strings.Loading) as String,
                null
            ),
            null,
            WatchUi.SLIDE_DOWN
        );
    }

    function onShow() as Void {
        _coordinator.onViewShown(self);
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
    }

    function hasPerished(haState as HaState) as Boolean {
        return haState.hasAreas();
    }
}
