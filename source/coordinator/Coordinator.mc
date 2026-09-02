import Toybox.Lang;
import Toybox.WatchUi;

class Coordinator {
    private const STALE_AFTER_MS = 60 * 1000;

    private var _client as HaClient;
    private var _haState as HaState;
    private var _currentView as Screen or Null;
    private var _subLabelProvider as SubLabelProvider;

    function initialize(client as HaClient) {
        _client = client;
        _haState = new HaState();
        _currentView = null;
        _subLabelProvider = new ResourceSubLabelProvider();
    }

    function onActivate() as Void {
        refresh();
    }

    function onViewShown(view as Screen) as Void {
        _currentView = view;
        updateDisplay();

        var age = _client.msSinceLastRefresh();
        if (age == null || age > STALE_AFTER_MS) {
            refresh();
        }
    }

    // A message screen is terminal — its only way forward is the user's manual
    // retry — so it is tracked but never refreshes itself.
    function onMessageShown(view as Screen) as Void {
        _currentView = view;
    }

    function onViewHidden(view as Screen) as Void {
        if (_currentView == view) {
            _currentView = null;
        }
    }

    function onToggleSettled(error as RequestError or Null) as Void {
        if (error != null) {
            WatchUi.showToast(ErrorMessage.resolve(error), null);
        }

        refresh();
    }

    function onFetchTarget(target as Symbol, result as Object or Null, isLastTarget as Boolean) as Void {
        if (result != null) {
            if (target == FetchTarget.STRUCTURE) {
                _haState.setZone(HaPayload.parseZone(result));
                _haState.setAreas(HaPayload.parseAreas(result));
                _haState.setFloors(HaPayload.parseFloors(result));
            } else if (target == FetchTarget.LIGHTS) {
                _haState.setLights(HaPayload.parseLights(result));
                GlanceSummary.setLightSummary(HaPayload.parseHomeLightSummary(result));
            } else if (target == FetchTarget.FANS) {
                _haState.setFans(HaPayload.parseFans(result));
            } else if (target == FetchTarget.SENSORS) {
                _haState.setSensors(HaPayload.parseSensors(result));
                _haState.setSensorAverages(
                    HaPayload.parseAverages(result, "areas"),
                    HaPayload.parseAverages(result, "floors"));
                var home = HaPayload.parseHomeAverages(result);
                GlanceSummary.setTemperature(home.get("temperature"));
                GlanceSummary.setHumidity(home.get("humidity"));
            }
        }

        updateDisplay();

        if (isLastTarget) {
            showDestination();
        }
    }

    function showAreaMenu(areaId as String) as Void {
        var model = AreaEntityMenuBuilder.build(_haState, areaId, _subLabelProvider);
        if (model == null) {
            return;
        }

        var menu = new AreaEntityMenu(self, areaId, model, _subLabelProvider);
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
        _client.queueToggle(entityId, new ToggleReply(self).method(:onSettled));
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

    // The state is emptied here, so whatever is on screen would draw a home with
    // nothing in it until the refresh settles.
    function discardRegistration() as Void {
        _client.cancelAll();
        _client.discardRegistration();
        _haState = new HaState();
        retry();
    }

    function retry() as Void {
        _currentView = null;
        WatchUi.switchToView(new LoadingView(self), new LoadingDelegate(), WatchUi.SLIDE_IMMEDIATE);
        refresh();
    }

    function showError(error as RequestError) as Void {
        showInfoView(WatchUi.loadResource(ErrorMessage.resolve(error)) as String, error.toDiagnosticCode());
    }

    function showMessage(id as ResourceId) as Void {
        showInfoView(WatchUi.loadResource(id) as String, null);
    }

    private function showInfoView(message as String, detail as String or Null) as Void {
        var infoView = new InfoView(self, message, true, detail);
        _currentView = infoView;
        WatchUi.switchToView(infoView, new InfoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }

    private function refresh() as Void {
        if (!Settings.isConfigured()) {
            showMessage(Rez.Strings.ErrNoConfig);
            return;
        }

        _client.refresh(method(:onFetchTarget));
    }

    private function showDestination() as Void {
        var error = _client.getError();

        if (_haState.hasAreas()) {
            if (_currentView == null) {
                showCardLoop();
            }

            if (error != null) {
                WatchUi.showToast(Rez.Strings.ErrRefresh, null);
            }

            return;
        }

        if (error != null) {
            showError(error);
            return;
        }

        if (_client.hasEverRefreshed()) {
            showMessage(Rez.Strings.NothingFound);
        }
    }

    private function updateDisplay() as Void {
        var view = _currentView;

        if (view == null) {
            return;
        }

        if (view has :hasPerished && (view as Perishable).hasPerished(_haState)) {
            showCardLoop();
            return;
        }

        if (view has :rebuild) {
            (view as Refreshable).rebuild(_haState);
            WatchUi.requestUpdate();
        }
    }

    private function showCardLoop() as Void {
        var loop = new CardLoop(self, CardLoopBuilder.build(_haState));
        WatchUi.switchToView(loop, new CardLoopDelegate(loop, self), WatchUi.SLIDE_IMMEDIATE);
    }
}
