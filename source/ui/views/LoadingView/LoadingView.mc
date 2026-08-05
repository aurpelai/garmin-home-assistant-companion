import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen and startup orchestrator: it runs the initial fetch and swaps
// itself for the card loop (or an error screen) once it completes.
class LoadingView extends WatchUi.View {
    private var _app as HaControllerApp;

    function initialize() {
        View.initialize();
        _app = Application.getApp() as HaControllerApp;
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
            showRetryScreen(Rez.Strings.ErrNoConfig, null);
            return;
        }

        _app.fetchHomeState(method(:onLoaded));
    }

    function onLoaded(state as HomeState or Null, error as Number or Null) as Void {
        if (error != null) {
            showRetryScreen(resolveErrorMessage(error), error);
            return;
        }

        if (state == null) {
            showRetryScreen(Rez.Strings.ErrNullHaState, null);
            return;
        }

        if (state.isEmpty()) {
            showRetryScreen(Rez.Strings.ErrEmptyHaState, null);
            return;
        }

        // Safe to swap the session wholesale only because this runs at
        // startup/retry, before any view holds it. Mid-session refresh must go
        // through applyState instead, or injected references would diverge.
        var session = _app.setSession(state);
        var cardLoopView = new CardLoopView(session);

        WatchUi.switchToView(
            cardLoopView,
            new CardLoopDelegate(cardLoopView, session),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    private function showRetryScreen(id as ResourceId, code as Number or Null) as Void {
        var message = WatchUi.loadResource(id) as String;

        if (code != null) {
            message = Lang.format(WatchUi.loadResource(Rez.Strings.ErrCode) as String, [code]) + "\n\n" + message;
        }

        WatchUi.switchToView(
            new ErrorView(message),
            new ErrorDelegate(),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function resolveErrorMessage(code as Number) as ResourceId {
        if (code == 401 || code == 403) {
            return Rez.Strings.ErrAuth;
        }

        if (code == 404) {
            return Rez.Strings.ErrNotFound;
        }

        if (code < 0) {
            return Rez.Strings.ErrNetwork;
        }

        return Rez.Strings.ErrUnknown;
    }
}
