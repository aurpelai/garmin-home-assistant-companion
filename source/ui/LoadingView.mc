import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen and startup orchestrator. onShow() (a View lifecycle callback the
// framework invokes) drives the initial load:
//   1. checks settings are present (else -> ErrorView with ErrNoConfig)
//   2. fetches the areas→lights map (POST /api/template)
//   3. fetches current on/off states (GET /api/states)
//   4. replaces itself with the AreaMenu
// Any request error routes to an ErrorView keyed on the HTTP/comm code.
class LoadingView extends WatchUi.View {
    private var _message as String;
    private var _client as HaClient;
    private var _map as AreaLightMap or Null;
    private var _started as Boolean;

    function initialize() {
        View.initialize();
        _message = WatchUi.loadResource(Rez.Strings.Loading) as String;
        _client = new HaClient();
        _map = null;
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
        _client.fetchAreaLightMap(method(:onMap));
    }

    function onMap(map as AreaLightMap or Null, err as Number or Null) as Void {
        if (err != null) { showError(errorStringFor(err)); return; }
        _map = map;
        setMessage(WatchUi.loadResource(Rez.Strings.LoadingLights) as String);
        _client.fetchStates(method(:onStates));
    }

    function onStates(states as Dictionary or Null, err as Number or Null) as Void {
        // A states failure is non-fatal — we can still show the menu without
        // live on/off icons. Fall back to an empty state map.
        var s = (err != null || states == null) ? ({} as Dictionary) : states;
        var store = new LightStore(_client, _map as AreaLightMap, s as Dictionary);
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
