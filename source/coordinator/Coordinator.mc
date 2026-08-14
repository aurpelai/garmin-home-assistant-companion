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
            showInfo(Rez.Strings.ErrNoConfig, null);
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
    //
    // A failure signals whatever is on screen, rather than deferring to the
    // grid: the override clears either way, so the row snaps back, and without
    // a signal that looks exactly like the app ignoring the tap.
    function onToggleSettled(overriddenIds as Array<String>, error as RequestError or Null) as Void {
        _haState.clearOverrides(overriddenIds);

        if (error != null) {
            signal(error);
        }

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

    // The info screen shows no Home Assistant data, so it is not a Screen and
    // nothing is live to push into while it is up.
    function showInfo(id as ResourceId, code as Object or Null) as Void {
        var message = WatchUi.loadResource(id) as String;

        if (code instanceof Number) {
            message = Lang.format(WatchUi.loadResource(Rez.Strings.ErrCode) as String, [code]) + ":\n" + message;
        }

        _currentView = null;
        WatchUi.switchToView(new InfoView(message), new InfoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }

    private function refresh() as Void {
        _client.refresh(method(:onFetchTarget));
    }

    // Every reply lands here, failures included: nothing else would prompt a
    // look at the client's last error, so a failure with nothing loaded would
    // leave the loading screen up forever.
    function onFetchTarget(target as Symbol, result as Object or Null, error as RequestError or Null) as Void {
        if (error == null) {
            if (target == :structure) {
                _haState.setStructure(HaPayload.parseStructure(result));
            } else if (target == :lights) {
                _haState.setLights(HaPayload.parseLights(result));
            } else if (target == :sensors) {
                _haState.setSensors(HaPayload.parseSensors(result));
            }
        }

        showDestination();
    }

    // The one navigation gate: the screen follows from three facts and no stored
    // status value. Reached only from a reply, so a signal here reports the
    // failure that just settled rather than re-announcing an old one.
    private function showDestination() as Void {
        var error = _client.lastError();

        switch (resolveDestination(_haState.hasEntities(), error, _client.hasCompletedARefresh())) {
            case :loading:
                break;

            case :nothingFound:
                showInfo(Rez.Strings.NothingFound, null);
                break;

            case :failure:
                var failure = error as RequestError;
                showInfo(resolveMessage(failure), failure.reason);
                break;

            case :realView:
                onStateChanged();
                break;

            case :realViewSignalled:
                onStateChanged();
                signal(error as RequestError);
                break;
        }
    }

    // Names the missing part where there is one, since the request type is
    // :fetch for all three targets and cannot say which failed.
    private function signal(error as RequestError) as Void {
        var message = WatchUi.loadResource(resolveMessage(error)) as String;
        var part = resolveMissingPart(error);

        if (part != null) {
            message = Lang.format(WatchUi.loadResource(Rez.Strings.ErrPart) as String,
                                  [WatchUi.loadResource(part), message]);
        }

        WatchUi.showToast(message, null);
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
