import Toybox.Lang;
import Toybox.WatchUi;

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

    function onViewHidden(view as Screen) as Void {
        if (_currentView == view) {
            _currentView = null;
        }
    }

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

        _haState.override(entityId, !_haState.isOn(entityId));
        _client.queueLightToggle(entityId, new ToggleReply(self).method(:onSettled));
        updateDisplay();
    }

    function toggleFloorLights(floorId as String) as Void {
        var lights = _haState.getLightsInFloor(floorId);
        if (lights.size() == 0 || _haState.hasAnyPending(_haState.toLightIds(lights))) {
            return;
        }

        var targetState = !_haState.hasAnyOn(lights);
        _haState.overrideFloorLights(floorId, targetState);
        var service = targetState ? "turn_on" : "turn_off";

        _client.queueFloorLights(floorId, service, new ToggleReply(self).method(:onSettled));
        updateDisplay();
    }

    function onToggleSettled(error as RequestError or Null) as Void {
        if (error != null) {
            toast(ErrorMessage.resolve(error));
        }

        refresh();
    }

    function discardRegistration() as Void {
        _client.cancelAll();
        _client.discardRegistration();
        _haState = new HaState();
        GlanceSummary.setLights(null);
        GlanceSummary.setClimate({});
        refresh();
    }

    function showError(error as RequestError) as Void {
        showInfoView(WatchUi.loadResource(ErrorMessage.resolve(error)) as String, error.toDiagnosticCode());
    }

    function showMessage(id as ResourceId) as Void {
        showInfoView(WatchUi.loadResource(id) as String, null);
    }

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

    function onFetchTarget(target as Symbol, result as Object or Null, isLastTarget as Boolean) as Void {
        if (result != null) {
            if (target == FetchTarget.STRUCTURE) {
                _haState.setZone(HaPayload.parseZone(result));
                _haState.setAreas(HaPayload.parseAreas(result));
                _haState.setFloors(HaPayload.parseFloors(result));
            } else if (target == FetchTarget.LIGHTS) {
                _haState.setLights(HaPayload.parseLights(result));
                _haState.setLightAggregates(
                    HaPayload.parseAreaLightCounts(result),
                    HaPayload.parseFloorLightSummaries(result),
                    HaPayload.parseHomeLightSummary(result));
                GlanceSummary.setLights(_haState.getHomeLightSummary());
            } else if (target == FetchTarget.SENSORS) {
                _haState.setSensors(HaPayload.parseSensors(result));
                _haState.setSensorAggregates(
                    HaPayload.parseMeans(result, "areas"),
                    HaPayload.parseMeans(result, "floors"),
                    HaPayload.parseHomeMeans(result));
                GlanceSummary.setClimate(_haState.getHomeMeans() as Dictionary);
            }
        }

        updateDisplay();

        if (isLastTarget) {
            showDestination();
        }
    }

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
