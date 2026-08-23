import Toybox.Lang;
import Toybox.WatchUi;

// Owns fetch policy, the client, view construction and navigation. A view asks
// it to toggle; it has HaState record the override, fires the request through
// HaClient, and on reply tells HaState to clear exactly the ids the override
// created. Retains no models — that is a view's job.
class Coordinator {
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

    function haState() as HaState {
        return _haState;
    }

    // A subject gone between the card being drawn and the tap landing leaves
    // nothing to open, so the tap is dropped rather than opening an empty menu.
    function showAreaMenu(areaId as String) as Void {
        var model = AreaEntityMenuBuilder.build(_haState, areaId);
        if (model == null) {
            return;
        }

        var menu = new AreaEntityMenu(self, areaId, model);
        WatchUi.pushView(menu, new AreaEntityMenuDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function showFloorMenu(floorId as String) as Void {
        var model = FloorEntityMenuBuilder.build(_haState, floorId);
        if (model == null) {
            return;
        }

        var menu = new FloorEntityMenu(self, floorId, model);
        WatchUi.pushView(menu, new FloorEntityMenuDelegate(menu, self), WatchUi.SLIDE_LEFT);
    }

    function toggleEntity(entityId as String) as Void {
        if (_haState.hasAnyPending(_haState.getToggleTargets(entityId))) {
            return;
        }

        var overriddenIds = _haState.override(entityId, !_haState.isOn(entityId));
        _client.queueLightToggle(entityId, new ToggleReply(self, overriddenIds).method(:onSettled));
        updateDisplay();
    }

    function toggleFloorLights(floorId as String) as Void {
        var lights = _haState.getLightsInFloor(floorId);
        if (lights.size() == 0 || _haState.hasAnyPending(_haState.toLightIds(lights))) {
            return;
        }

        var targetState = !_haState.hasAnyOn(lights);
        var overriddenIds = _haState.overrideFloorLights(floorId, targetState);
        var service = targetState ? "turn_on" : "turn_off";

        _client.queueFloorLights(floorId, service, new ToggleReply(self, overriddenIds).method(:onSettled));
        updateDisplay();
    }

    // A failure signals here rather than deferring to the destination below:
    // the override clears either way, so the row snaps back, and without a
    // signal that looks exactly like the app ignoring the tap.
    function onToggleSettled(overriddenIds as Array<String>, error as RequestError or Null) as Void {
        _haState.clearOverrides(overriddenIds);

        if (error != null) {
            toast(ErrorMessage.resolve(error));
        }

        updateDisplay();
        refresh();
    }

    // A token change is as disqualifying as a URL change: Home Assistant's
    // visibility is per-user, so the entities behind a new token may differ.
    function discardRegistration() as Void {
        _client.cancelAll();
        _client.discardRegistration();
        _haState = new HaState();
        refresh();
    }

    function showError(error as RequestError) as Void {
        showInfoView(WatchUi.loadResource(ErrorMessage.resolve(error)) as String, error.toDiagnosticCode());
    }

    function showMessage(id as ResourceId) as Void {
        showInfoView(WatchUi.loadResource(id) as String, null);
    }

    // The info screen shows no Home Assistant data, so it is not a Screen and
    // nothing is live to push into while it is up.
    private function showInfoView(message as String, detail as String or Null) as Void {
        _currentView = null;
        WatchUi.switchToView(new InfoView(message, true, detail), new InfoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }

    private function refresh() as Void {
        if (!Settings.isConfigured()) {
            showMessage(Rez.Strings.ErrNoConfig);
            return;
        }

        _client.refresh(method(:onFetchTarget));
    }

    // Every reply lands here, failures included. Each target reaches the screen
    // as it lands, so partial data is visible while the rest is in flight, but
    // where the user belongs is a question about the refresh rather than about
    // one reply — so it waits for the last one.
    function onFetchTarget(target as Symbol, result as Object or Null, isLastTarget as Boolean) as Void {
        if (result != null) {
            if (target == FetchTarget.STRUCTURE) {
                _haState.setZone(HaPayload.parseZone(result));
                _haState.setAreas(HaPayload.parseAreas(result));
                _haState.setFloors(HaPayload.parseFloors(result));
            } else if (target == FetchTarget.LIGHTS) {
                _haState.setLights(HaPayload.parseLights(result));
            } else if (target == FetchTarget.SENSORS) {
                _haState.setSensors(HaPayload.parseSensors(result));
            }
        }

        updateDisplay();

        if (isLastTarget) {
            showDestination();
        }
    }

    // The one navigation gate, reached once a refresh has settled so the result
    // it reads is final rather than mid-flight.
    private function showDestination() as Void {
        var result = _client.refreshResult();

        if (_haState.hasAreas()) {
            if (_currentView == null) {
                showCardLoop();
            }

            if (result.error != null) {
                toast(Rez.Strings.ErrRefresh);
            }

            return;
        }

        if (result.error != null) {
            showError(result.error as RequestError);
            return;
        }

        if (result.hasEverCompleted) {
            showMessage(Rez.Strings.NothingFound);
        }
    }

    private function toast(id as ResourceId) as Void {
        WatchUi.showToast(WatchUi.loadResource(id) as String, null);
    }

    // An obsolete view lands on the card loop, which builds from the whole of
    // HaState and so is the one screen no deletion can empty.
    private function updateDisplay() as Void {
        var view = _currentView;

        if (view == null) {
            return;
        }

        if (view.isObsolete(_haState)) {
            showCardLoop();
            return;
        }

        view.rebuild(_haState);
        WatchUi.requestUpdate();
    }

    private function showCardLoop() as Void {
        var loop = new CardLoop(self, CardLoopBuilder.build(_haState));
        WatchUi.switchToView(loop, new CardLoopDelegate(loop, self), WatchUi.SLIDE_IMMEDIATE);
    }
}
