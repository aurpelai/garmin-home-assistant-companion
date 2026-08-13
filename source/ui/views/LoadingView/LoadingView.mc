import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen and startup orchestrator: it runs the initial fetch and swaps
// itself for the card loop (or an error screen) once it completes.
class LoadingView extends WatchUi.View {
    private var _app as HaCompanionApp;

    function initialize() {
        View.initialize();
        _app = Application.getApp() as HaCompanionApp;
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
        if (!Settings.isConfigured()) {
            _app.showRetryScreen(Rez.Strings.ErrNoConfig, null);
            return;
        }

        _app.fetchHomeState();
    }
}
