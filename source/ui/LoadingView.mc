import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen and startup orchestrator. onShow() (a View lifecycle callback the
// framework invokes) drives the initial load:
//   1. checks settings are present (else -> ErrorView with ErrNoConfig)
//   2. fetches the light snapshot — areas→lights and current on/off states in a
//      single POST /api/template
//   3. replaces itself with the AreaMenu
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
            showError(Rez.Strings.ErrNoConfig);
            return;
        }
        setMessage(WatchUi.loadResource(Rez.Strings.LoadingAreas) as String);
        _client.fetchLightSnapshot(method(:onLoaded));
    }

    // On any request/transport error the client invokes us with (null, code), so a
    // non-null err is the only failure path — a null snapshot never arrives alongside
    // a null err.
    function onLoaded(snapshot as LightSnapshot or Null, err as Number or Null) as Void {
        if (err != null) { showError(errorStringFor(err)); return; }
        var store = new LightStore(_client, snapshot as LightSnapshot);
        WatchUi.switchToView(new AreaMenu(store), new AreaMenuDelegate(store),
            WatchUi.SLIDE_IMMEDIATE);
    }

    function setMessage(msg as String) as Void {
        _message = msg;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        TextDraw.centeredMessage(dc, _message);
    }

    private function showError(resId as ResourceId) as Void {
        var msg = WatchUi.loadResource(resId) as String;
        WatchUi.switchToView(new ErrorView(msg), new ErrorDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    private function errorStringFor(code as Number) as ResourceId {
        if (code == 401 || code == 403) { return Rez.Strings.ErrAuth; }
        if (code < 0) { return Rez.Strings.ErrNetwork; }
        return Rez.Strings.ErrUnknown;
    }
}
