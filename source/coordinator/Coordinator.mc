import Toybox.Lang;
import Toybox.WatchUi;

// Owns fetch policy, the client, view construction and navigation. A view asks
// it to toggle; it has HaState record the override, fires the request through
// HaClient, and on reply tells HaState to clear exactly the ids the override
// created. Retains no models — that is a view's job.
class Coordinator {
    // How long a completed refresh may be trusted before a view reveal
    // triggers another one.
    private const STALE_AFTER_MS = 60 * 1000;

    private var _client as HaClient;
    private var _haState as HaState;
    private var _currentView as Screen or Null;

    function initialize(client as HaClient) {
        _client = client;
        _haState = new HaState();
        _currentView = null;
    }

    function onActivate() as Void {
        refresh();
    }

    // The loading screen's own reveal. Configuration is checked here rather than
    // on every reveal because only a settings change can alter it, and that
    // rebuilds from the loading screen anyway.
    function onLaunch(view as Screen) as Void {
        if (!Settings.isConfigured()) {
            showRetryScreen(Rez.Strings.ErrNoConfig, null);
            return;
        }

        onViewShown(view);
    }

    // Called on a view reveal; fetches only when the last completed refresh
    // is older than the staleness window, never because of what kind of
    // navigation revealed the view.
    function onViewShown(view as Screen) as Void {
        _currentView = view;

        var age = _client.msSinceLastRefresh();
        if (age == null || age > STALE_AFTER_MS) {
            refresh();
        }
    }

    // Order-independent: a stale hide from a view already replaced as current
    // must not clear the view that replaced it.
    function onViewHidden(view as Screen) as Void {
        if (_currentView == view) {
            _currentView = null;
        }
    }

    function currentView() as Screen or Null {
        return _currentView;
    }

    // What the builders read. Handing the state out rather than proxying every
    // question keeps them plain functions; the coordinator stays the only writer,
    // since the rebuild sequence replaces this field wholesale.
    function haState() as HaState {
        return _haState;
    }

    // A subject gone between the card being drawn and the tap landing leaves
    // nothing to open, so the tap is dropped rather than opening an empty menu.
    function showArea(areaId as String) as Void {
        var model = buildAreaEntityMenuModel(_haState, areaId);
        if (model == null) {
            return;
        }

        var menu = new AreaEntityMenu(self, areaId, model);
        WatchUi.pushView(menu, new AreaEntityMenuDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function showFloor(floorId as String) as Void {
        var model = buildFloorEntityMenuModel(_haState, floorId);
        if (model == null) {
            return;
        }

        var menu = new FloorEntityMenu(self, floorId, model);
        WatchUi.pushView(menu, new FloorEntityMenuDelegate(menu, self), WatchUi.SLIDE_LEFT);
    }

    // Ignored while anything the tap would cover is already pending, regardless of
    // what created that override: one in-flight change per entity, and a group's
    // scope reaches its members.
    function toggleEntity(entityId as String) as Void {
        if (_haState.anyPending(_haState.entityScope(entityId))) {
            return;
        }

        var overriddenIds = _haState.override(entityId, !_haState.isOn(entityId));
        _client.queueLightToggle(entityId, new ToggleReply(self, overriddenIds).method(:onSettled));
        onStateChanged();
    }

    function toggleFloorLights(floorId as String) as Void {
        var lightIds = _haState.getLightIdsInFloor(floorId);
        if (lightIds.size() == 0 || _haState.anyPending(lightIds)) {
            return;
        }

        var targetState = !_haState.anyOn(lightIds);
        var overriddenIds = _haState.overrideFloorLights(floorId, targetState);
        var service = targetState ? "turn_on" : "turn_off";

        _client.queueFloorLights(floorId, service, new ToggleReply(self, overriddenIds).method(:onSettled));
        onStateChanged();
    }

    // A toggle reply is one of the three refresh triggers: every terminal
    // outcome clears its own override, then a refresh reconverges with
    // whatever Home Assistant actually did.
    function onToggleSettled(overriddenIds as Array<String>) as Void {
        _haState.clearOverrides(overriddenIds);
        onStateChanged();
        refresh();
    }

    // The rebuild sequence: cancel everything in flight, discard HaState, and
    // start over from empty. No comparison against the previous URL or token —
    // a settings change is disqualifying on its own, and a token change is as
    // disqualifying as a URL change, since Home Assistant's visibility is
    // per-user.
    function onSettingsChanged() as Void {
        _client.cancelAll();
        _haState = new HaState();
        refresh();
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

    function showRetryScreen(id as ResourceId, code as Number or Null) as Void {
        var message = WatchUi.loadResource(id) as String;

        if (code != null) {
            message = Lang.format(WatchUi.loadResource(Rez.Strings.ErrCode) as String, [code]) + ":\n" + message;
        }

        WatchUi.switchToView(new ErrorView(message), new ErrorDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }

    private function refresh() as Void {
        _client.refresh(method(:onFetchTarget));
    }

    function onFetchTarget(target as Symbol, result as Object or Null, error as Number or Null) as Void {
        if (error != null) {
            return;
        }

        if (target == :structure) {
            _haState.setStructure(HaPayload.parseStructure(result));
        } else if (target == :lights) {
            _haState.setLights(HaPayload.parseLights(result));
        } else if (target == :sensors) {
            _haState.setSensors(HaPayload.parseSensors(result));
        }

        onStateChanged();
    }

    // The one push site. A view whose subject is gone says so, and the card loop
    // is where that leaves the user: it builds from the whole of HaState, so it
    // is the one screen no deletion can empty out from under.
    private function onStateChanged() as Void {
        var view = _currentView;
        if (view == null) {
            return;
        }

        if (view.rebuild(_haState)) {
            WatchUi.requestUpdate();
            return;
        }

        var loop = new CardLoop(self, buildCardLoopModel(_haState));
        WatchUi.switchToView(loop, new CardLoopDelegate(loop, self), WatchUi.SLIDE_IMMEDIATE);
    }
}
