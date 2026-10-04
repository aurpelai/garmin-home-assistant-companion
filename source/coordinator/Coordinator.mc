import Toybox.Lang;
import Toybox.WatchUi;

class Coordinator {
    private const DOUBLE_CLICK_MS = 250;

    private var _client as HaClient;
    private var _haState as HaState;
    private var _currentView as Screen or Null;
    private var _subLabelProvider as SubLabelProvider;
    private var _clickDebounce as Scheduler;
    private var _pendingClickId as String or Null;
    private var _hasVisibilityChanged as Boolean;

    function initialize(client as HaClient, haState as HaState, clickDebounce as Scheduler) {
        _client = client;
        _haState = haState;
        _currentView = null;
        _subLabelProvider = new ResourceSubLabelProvider();
        _clickDebounce = clickDebounce;
        _pendingClickId = null;
        _hasVisibilityChanged = false;
        _haState.setHidden(VisibilityStore.getHiddenFloors(), VisibilityStore.getHiddenAreas());
        _haState.setIncludedLabels(VisibilityStore.getIncludedLabels());
    }

    function onActivate() as Void {
        refresh();
    }

    function onViewShown(view as Screen) as Void {
        _currentView = view;
        updateDisplay();

        if (_hasVisibilityChanged || _client.isRefreshDue()) {
            _hasVisibilityChanged = false;
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

    function onToggleSettled(result as Object or Null, error as RequestError or Null) as Void {
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
                _haState.setLabels(HaPayload.parseLabels(result));
            } else if (target == FetchTarget.LIGHTS) {
                _haState.setToggleables(Domain.LIGHT, HaPayload.parseLights(result));
                GlanceSummary.setLightSummary(HaPayload.parseLightSummary(result));
            } else if (target == FetchTarget.FANS) {
                _haState.setToggleables(Domain.FAN, HaPayload.parseFans(result));
            } else if (target == FetchTarget.SENSORS) {
                _haState.setSensors(HaPayload.parseSensors(result));
                _haState.setSensorAverages(
                    HaPayload.parseAverages(result, "areas"),
                    HaPayload.parseAverages(result, "floors"));
                var climate = HaPayload.parseClimate(result);
                GlanceSummary.setTemperature(climate.get("temperature"));
                GlanceSummary.setHumidity(climate.get("humidity"));
            }
        }

        updateDisplay();

        if (isLastTarget) {
            onRefreshSettled();
        }
    }

    function showAreaMenu(areaId as String) as Void {
        var area = _haState.getArea(areaId);
        if (area == null) {
            return;
        }

        var model = EntityMenuBuilder.build(area.name, _haState.getToggleablesInArea(areaId),
            _haState.getSensorsInArea(areaId), _subLabelProvider);
        var menu = new AreaEntityMenu(self, areaId, model, _subLabelProvider);
        WatchUi.pushView(menu, new AreaEntityMenuDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function showLabelsMenu() as Void {
        if (!_haState.hasEntitiesOfIncludedLabels()) {
            return;
        }

        var model = LabelsMenuBuilder.build(WatchUi.loadResource(Rez.Strings.LabelsCardTitle) as String,
            _haState, WatchUi.loadResource(Rez.Strings.Other) as String, _subLabelProvider);
        var menu = new LabelsMenu(self, model, _subLabelProvider);
        WatchUi.pushView(menu, new AreaEntityMenuDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function buildSettingsMenu() as [WatchUi.Views, WatchUi.InputDelegates] {
        return [new SettingsMenu(_haState), new SettingsMenuDelegate(self)];
    }

    function showLabelPicker() as Void {
        if (!_haState.hasLabels()) {
            return;
        }

        var rows = LabelPickerBuilder.build(_haState);
        var menu = new LabelPicker(rows);
        WatchUi.pushView(menu, new LabelPickerDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function showVisibilityPicker() as Void {
        if (!_haState.hasAreas()) {
            return;
        }

        var rows = VisibilityPickerBuilder.build(
            _haState, WatchUi.loadResource(Rez.Strings.Other) as String);
        var menu = new VisibilityPicker(rows);
        WatchUi.pushView(menu, new VisibilityPickerDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function onSettingsClosed() as Void {
        if (_hasVisibilityChanged) {
            _hasVisibilityChanged = false;
            _haState.clearFetched();
            retry();
        }
    }

    function showFloorMenu(floorId as String) as Void {
        var model = FloorEntityMenuBuilder.build(_haState, floorId);
        if (model == null) {
            return;
        }

        var menu = new FloorEntityMenu(self, floorId, model);
        WatchUi.pushView(menu, new FloorEntityMenuDelegate(menu, self), WatchUi.SLIDE_LEFT);
    }

    function onEntityClick(entityId as String) as Void {
        var pending = _pendingClickId;
        clearPendingClick();

        if (pending != null && pending.equals(entityId)) {
            showAttributeMenu(entityId);
            return;
        }

        if (pending != null) {
            toggleEntity(pending);
        }

        _pendingClickId = entityId;
        _clickDebounce.schedule(method(:flushPendingClick), DOUBLE_CLICK_MS);
    }

    function flushPendingClick() as Void {
        var entityId = _pendingClickId;
        clearPendingClick();

        if (entityId != null) {
            toggleEntity(entityId);
        }
    }

    function isOn(entityId as String) as Boolean {
        return _haState.isOn(entityId);
    }

    function setFloorVisibility(floorId as String, isVisible as Boolean) as Void {
        _haState.setFloorVisibility(floorId, isVisible);
        persistVisibility();
    }

    function setAreaVisibility(areaId as String, isVisible as Boolean) as Void {
        _haState.setAreaVisibility(areaId, isVisible);
        persistVisibility();
    }

    function setIncludedLabel(labelId as String, isIncluded as Boolean) as Void {
        _haState.setIncludedLabel(labelId, isIncluded);
        persistVisibility();
    }

    function setAttribute(attribute as AdjustableAttribute, value as Number) as Void {
        commitAttribute(attribute, attribute.selectService(value), value);
    }

    function toggleAttribute(attribute as AdjustableAttribute, isOn as Boolean) as Void {
        commitAttribute(attribute, attribute.service, isOn);
    }

    function toggleEntity(entityId as String) as Void {
        if (_haState.hasAnyPending(_haState.resolveToggleTargets(entityId))) {
            return;
        }

        _haState.overrideState(entityId, !_haState.isOn(entityId));
        _client.queueToggle(entityId, method(:onToggleSettled));
        updateDisplay();
    }

    function toggleFloorLights(floorId as String) as Void {
        var lights = _haState.listVisibleToggleablesInFloor(floorId, Domain.LIGHT);
        if (lights.size() == 0 || _haState.hasAnyPending(_haState.toIds(lights))) {
            return;
        }

        var targetState = !_haState.hasAnyOn(lights);
        _haState.overrideFloorLightsState(floorId, targetState);
        var service = targetState ? "turn_on" : "turn_off";

        _client.queueLightsInAreas(_haState.listVisibleAreaIdsInFloor(floorId), service,
            method(:onToggleSettled));
        updateDisplay();
    }

    // The state is emptied here, so whatever is on screen would draw a home with
    // nothing in it until the refresh settles.
    function discardRegistration() as Void {
        _client.cancelAll();
        _client.discardRegistration();
        _haState.clearFetched();
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

    private function commitAttribute(attribute as AdjustableAttribute, service as String,
                                     value as Object) as Void {
        _haState.overrideAttribute(attribute.entityId, attribute.field, value);
        _client.queueAttribute(attribute.domain, service, attribute.entityId,
            attribute.field, value, method(:onToggleSettled));
        updateDisplay();
    }

    private function showAttributeMenu(entityId as String) as Void {
        var toggleable = _haState.getToggleable(entityId);
        if (toggleable == null) {
            return;
        }

        var attributes = AttributeBuilder.build(toggleable);
        if (attributes.size() == 0) {
            return;
        }

        WatchUi.showActionMenu(
            EntityActionMenu.build(attributes), new EntityActionMenuDelegate(self, attributes));
    }

    private function clearPendingClick() as Void {
        _pendingClickId = null;
        _clickDebounce.cancel();
    }

    private function persistVisibility() as Void {
        _hasVisibilityChanged = true;
        VisibilityStore.setHiddenFloors(_haState.getHiddenFloors());
        VisibilityStore.setHiddenAreas(_haState.getHiddenAreas());
        VisibilityStore.setIncludedLabels(_haState.getIncludedLabels());
    }

    private function showInfoView(message as String, detail as String or Null) as Void {
        var infoView = new InfoView(self, message, true, detail);
        _currentView = infoView;
        WatchUi.switchToView(infoView, new InfoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }

    private function refresh() as Void {
        if (!Settings.isConfigured()) {
            showMessage(Rez.Strings.ErrorNoConfig);
            return;
        }

        _client.refresh(method(:onFetchTarget));
    }

    private function onRefreshSettled() as Void {
        var error = _client.getError();

        if (_haState.hasAreas()) {
            if (_currentView == null) {
                showCardLoop();
            }

            if (error != null) {
                WatchUi.showToast(Rez.Strings.ErrorRefresh, null);
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
            (view as Rebuildable).rebuild(_haState);
            WatchUi.requestUpdate();
        }
    }

    private function showCardLoop() as Void {
        var loop = new CardLoop(self, CardLoopBuilder.build(_haState));
        WatchUi.switchToView(loop, new CardLoopDelegate(loop, self), WatchUi.SLIDE_IMMEDIATE);
    }
}
