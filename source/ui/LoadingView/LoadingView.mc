import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen and startup orchestrator: it runs the initial fetch and swaps
// itself for the card loop (or an error screen) once it completes.
class LoadingView extends WatchUi.View {
    private var _message as String;
    private var _client as HaClient;
    private var _started as Boolean;

    function initialize() {
        View.initialize();
        _message = WatchUi.loadResource(Rez.Strings.Loading) as String;
        _client = new HaClient();
        _started = false;
    }

    function onShow() as Void {
        if (_started) {
            return;
        }

        _started = true;

        if (!Settings.isConfigured()) {
            showRetryScreen(Rez.Strings.ErrNoConfig, null);
            return;
        }
        setMessage(WatchUi.loadResource(Rez.Strings.LoadingAreas) as String);
        _client.fetchHomeState(method(:onLoaded));
    }

    // The client signals failure only as a non-null error; state is never null
    // when error is null.
    function onLoaded(state as HomeState or Null, error as Number or Null) as Void {
        if (error != null) {
            showRetryScreen(resolveErrorMessage(error), error);
            return;
        }

        var loaded = state as HomeState;
        if (loaded.isEmpty()) {
            showRetryScreen(Rez.Strings.NoEntitiesInAnyArea, null);
            return;
        }

        var session = new HomeSession(_client, loaded);
        // Safe to swap the session wholesale only because this runs at
        // startup/retry, before any view holds it. Mid-session refresh must go
        // through applyState instead, or injected references would diverge.
        (Application.getApp() as HaControllerApp).setSession(session);
        var view = new CardLoopView(session);
        WatchUi.switchToView(view, new CardLoopDelegate(view, session),
            WatchUi.SLIDE_IMMEDIATE);
    }

    function setMessage(message as String) as Void {
        _message = message;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        CenteredMessage.draw(dc, _message);
    }

    private function showRetryScreen(id as ResourceId, code as Number or Null) as Void {
        var message = WatchUi.loadResource(id) as String;

        if (code != null) {
            message = WatchUi.loadResource(id) as String + "\n\n" + code;
        }

        WatchUi.switchToView(new ErrorView(message), new ErrorDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function resolveErrorMessage(code as Number) as ResourceId {
        if (code == 401 || code == 403) {
            return Rez.Strings.ErrAuth;
        }

        if (code < 0) {
            return Rez.Strings.ErrNetwork;
        }

        return Rez.Strings.ErrUnknown;
    }
}
