import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

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
}
