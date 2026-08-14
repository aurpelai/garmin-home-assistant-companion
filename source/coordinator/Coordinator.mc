import Toybox.Lang;

// Owns fetch policy, the client, and the current-view fact. A view asks it to
// toggle; it has HaState record the override, fires the request through
// HaClient, and on reply tells HaState to clear exactly the ids the override
// created. Retains no models — that is a view's job.
class Coordinator {
    // How long a completed refresh may be trusted before a view reveal
    // triggers another one.
    private const STALE_AFTER_MS = 60 * 1000;

    private var _client as HaClient;
    private var _haState as HaState;
    private var _currentView as Object or Null;

    function initialize(client as HaClient) {
        _client = client;
        _haState = new HaState();
        _currentView = null;
    }

    function onActivate() as Void {
        refresh();
    }

    // Called on a view reveal; fetches only when the last completed refresh
    // is older than the staleness window, never because of what kind of
    // navigation revealed the view.
    function onViewShown(view as Object) as Void {
        _currentView = view;

        var age = _client.msSinceLastRefresh();
        if (age == null || age > STALE_AFTER_MS) {
            refresh();
        }
    }

    // Order-independent: a stale hide from a view already replaced as current
    // must not clear the view that replaced it.
    function onViewHidden(view as Object) as Void {
        if (_currentView == view) {
            _currentView = null;
        }
    }

    function currentView() as Object or Null {
        return _currentView;
    }

    // What the builders read. Handing the state out rather than proxying every
    // question keeps them plain functions; the coordinator stays the only writer,
    // since the rebuild sequence replaces this field wholesale.
    function haState() as HaState {
        return _haState;
    }

    function toggleEntity(entityId as String) as Void {
        if (_haState.isPending(entityId)) {
            return;
        }

        var overriddenIds = _haState.override(entityId, !_haState.isOn(entityId));
        _client.queueLightToggle(entityId, new ToggleReply(self, overriddenIds).method(:onSettled));
    }

    function toggleFloorLights(floorId as String) as Void {
        // Already covered if any commandable member is pending, regardless of
        // what created that override — a floor action creates many overrides,
        // so the same one-in-flight-per-entity rule applies to the whole scope.
        if (anyCommandableFloorLightPending(floorId)) {
            return;
        }

        var targetState = !anyCommandableFloorLightOn(floorId);
        var overriddenIds = _haState.overrideFloorLights(floorId, targetState);
        if (overriddenIds.size() == 0) {
            return;
        }

        var service = targetState ? "turn_on" : "turn_off";
        _client.queueFloorLights(floorId, service, new ToggleReply(self, overriddenIds).method(:onSettled));
    }

    // A toggle reply is one of the three refresh triggers: every terminal
    // outcome clears its own override, then a refresh reconverges with
    // whatever Home Assistant actually did.
    function onToggleSettled(overriddenIds as Array<String>) as Void {
        _haState.clearOverrides(overriddenIds);
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

    // Judged over the scope the call will actually command, so an unavailable
    // light Home Assistant still reports as on cannot decide the direction for
    // lights the call can reach.
    private function anyCommandableFloorLightOn(floorId as String) as Boolean {
        var lightIds = _haState.commandableFloorLightIds(floorId);

        for (var index = 0; index < lightIds.size(); index++) {
            if (_haState.isOn(lightIds[index])) {
                return true;
            }
        }

        return false;
    }

    private function anyCommandableFloorLightPending(floorId as String) as Boolean {
        var lightIds = _haState.commandableFloorLightIds(floorId);

        for (var index = 0; index < lightIds.size(); index++) {
            if (_haState.isPending(lightIds[index])) {
                return true;
            }
        }

        return false;
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
    }
}
