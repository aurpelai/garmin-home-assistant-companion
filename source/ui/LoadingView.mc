import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen and startup orchestrator. onShow() (a View lifecycle callback the
// framework invokes) drives the initial load:
//   1. checks settings are present (else -> ErrorView with ErrNoConfig)
//   2. fetches the home state — each area's lights and sensors, with their
//      states and readings, in a single POST /api/template
//   3. replaces itself with the AreaMenu, or with a message when no area holds
//      anything the app can show
// Any request error routes to an ErrorView keyed on the HTTP/comm code.
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

    // Framework lifecycle: fires when this view becomes visible. Kick off the
    // load exactly once.
    function onShow() as Void {
        if (_started) { return; }
        _started = true;

        if (!Settings.isConfigured()) {
            showRetryScreen(Rez.Strings.ErrNoConfig);
            return;
        }
        setMessage(WatchUi.loadResource(Rez.Strings.LoadingAreas) as String);
        _client.fetchHomeState(method(:onLoaded));
    }

    // On any request/transport error the client invokes us with (null, code), so a
    // non-null error is the only failure path — a null state never arrives alongside
    // a null error.
    function onLoaded(state as HomeState or Null, error as Number or Null) as Void {
        if (error != null) { showRetryScreen(resolveErrorMessage(error)); return; }

        var loaded = state as HomeState;
        if (loaded.isEmpty()) {
            showRetryScreen(Rez.Strings.NoEntitiesInAnyArea);
            return;
        }

        var session = new HomeSession(_client, loaded);
        // Replacing the app-owned session wholesale is safe ONLY because
        // onLoaded runs solely at startup/retry, with no live state-view holding
        // the prior session. Mid-session refresh MUST go through
        // onActive/applyState (in place), never here — else the app reference and
        // a view's constructor-injected reference would diverge.
        (Application.getApp() as HaControllerApp).setSession(session);
        WatchUi.switchToView(new AreaMenu(session), new AreaMenuDelegate(session),
            WatchUi.SLIDE_IMMEDIATE);
    }

    function setMessage(message as String) as Void {
        _message = message;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        CenteredMessage.draw(dc, _message);
    }

    private function showRetryScreen(id as ResourceId) as Void {
        var message = WatchUi.loadResource(id) as String;
        WatchUi.switchToView(new ErrorView(message), new ErrorDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function resolveErrorMessage(code as Number) as ResourceId {
        if (code == 401 || code == 403) { return Rez.Strings.ErrAuth; }
        if (code < 0) { return Rez.Strings.ErrNetwork; }
        return Rez.Strings.ErrUnknown;
    }
}
