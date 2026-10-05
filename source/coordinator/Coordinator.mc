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
    private var _isMessageShown as Boolean;

    function initialize(client as HaClient, haState as HaState, clickDebounce as Scheduler) {
        _client = client;
        _haState = haState;
        _currentView = null;
        _subLabelProvider = new ResourceSubLabelProvider();
        _clickDebounce = clickDebounce;
        _pendingClickId = null;
        _hasVisibilityChanged = false;
        _isMessageShown = false;
        _haState.setHidden(VisibilityStore.getHiddenFloors(), VisibilityStore.getHiddenAreas());
        _haState.setIncludedLabels(VisibilityStore.getIncludedLabels());
    }

    function onActivate() as Void {
        if (!_isMessageShown && _client.isRefreshDue()) {
            refresh();
        }
    }

    function onViewShown(view as Screen) as Void {
        _currentView = view;
        _isMessageShown = false;
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
        _isMessageShown = true;
    }

    function onViewHidden(view as Screen) as Void {
        if (_currentView == view) {
            _currentView = null;
        }
    }

    function onTargetSettled(target as Symbol, result as Object or Null, isSettled as Boolean) as Void {
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

        if (isSettled) {
            onRefreshSettled();
        }
    }

    function onToggleSettled(result as Object or Null, error as RequestError or Null) as Void {
        if (error != null) {
            WatchUi.showToast(ErrorMessage.resolve(error), null);
        }
    }

    function onSettingsClosed() as Void {
        if (_hasVisibilityChanged) {
            _hasVisibilityChanged = false;
            reload();
        }
    }

    function onEntityClick(entityId as String) as Void {
        var pending = _pendingClickId;
        cancelPendingClick();

        if (pending != null && pending.equals(entityId)) {
            showAttributeMenu(entityId);
            return;
        }

        if (pending != null) {
            toggleEntity(pending);
        }

        _pendingClickId = entityId;
        _clickDebounce.schedule(method(:onSingleClick), DOUBLE_CLICK_MS);
    }

    function onSingleClick() as Void {
        var entityId = _pendingClickId;
        cancelPendingClick();

        if (entityId != null) {
            toggleEntity(entityId);
        }
    }

    function isOn(entityId as String) as Boolean {
        return _haState.isOn(entityId);
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

    function showFloorMenu(floorId as String) as Void {
        var model = FloorEntityMenuBuilder.build(_haState, floorId);
        if (model == null) {
            return;
        }

        var menu = new FloorEntityMenu(self, floorId, model);
        WatchUi.pushView(menu, new FloorEntityMenuDelegate(menu, self), WatchUi.SLIDE_LEFT);
    }

    function showSettingsMenu() as Void {
        WatchUi.pushView(new SettingsMenu(_haState), new SettingsMenuDelegate(self), WatchUi.SLIDE_LEFT);
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

    function showError(errors as Array<RequestError>) as Void {
        var codes = [] as Array<String>;

        for (var i = 0; i < errors.size(); i++) {
            var code = errors[i].toDiagnosticCode();

            if (codes.indexOf(code) == -1) {
                codes.add(code);
            }
        }

        showInfoView(WatchUi.loadResource(ErrorMessage.resolveCommon(errors)) as String, codes);
    }

    function showMessage(id as ResourceId) as Void {
        showInfoView(WatchUi.loadResource(id) as String, []);
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
        _client.sendToggle(entityId, method(:onToggleSettled));
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

        _client.sendLightsInAreas(_haState.listVisibleAreaIdsInFloor(floorId), service,
            method(:onToggleSettled));
        updateDisplay();
    }

    function discardRegistration() as Void {
        _client.cancelAll();
        _client.discardRegistration();
        reload();
    }

    // The state is emptied here, so whatever is on screen would draw a home with
    // nothing in it until the refresh settles.
    function reload() as Void {
        _haState.clearFetched();
        _currentView = null;
        WatchUi.switchToView(new LoadingView(self), new LoadingDelegate(), WatchUi.SLIDE_IMMEDIATE);
        refresh();
    }

    private function refresh() as Void {
        if (!Settings.isConfigured()) {
            showMessage(Rez.Strings.ErrorNoConfig);
            return;
        }

        _client.refresh(method(:onTargetSettled));
    }

    private function onRefreshSettled() as Void {
        var errors = _client.getErrors();

        if (_haState.isHomeFullyLoaded()) {
            if (errors.size() > 0) {
                WatchUi.showToast(Rez.Strings.ErrorRefresh, null);
            }

            return;
        }

        if (errors.size() > 0) {
            showError(errors);
            return;
        }

        _haState.markHomeFullyLoaded();
        var model = CardLoopBuilder.build(_haState);

        if (model.cards.size() == 0) {
            showMessage(Rez.Strings.NothingFound);
            return;
        }

        showCardLoop(model);
    }

    private function updateDisplay() as Void {
        var view = _currentView;

        if (view == null) {
            return;
        }

        if (view has :hasPerished && (view as Perishable).hasPerished(_haState)) {
            showCardLoop(CardLoopBuilder.build(_haState));
            return;
        }

        if (view has :rebuild) {
            (view as Rebuildable).rebuild(_haState);
            WatchUi.requestUpdate();
        }
    }

    private function showCardLoop(model as CardLoopModel) as Void {
        var loop = new CardLoop(self, model);
        WatchUi.switchToView(loop, new CardLoopDelegate(loop, self), WatchUi.SLIDE_IMMEDIATE);
    }

    private function showInfoView(message as String, codes as Array<String>) as Void {
        var infoView = new InfoView(self, message, true, codes);
        _currentView = infoView;
        WatchUi.switchToView(infoView, new InfoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
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

    private function commitAttribute(attribute as AdjustableAttribute, service as String,
                                     value as Object) as Void {
        if (_haState.hasAnyPending(_haState.resolveToggleTargets(attribute.entityId))) {
            return;
        }

        _haState.overrideAttribute(attribute.entityId, attribute.field, value);
        _client.sendAttribute(attribute.domain, service, attribute.entityId,
            attribute.field, value, method(:onToggleSettled));
        updateDisplay();
    }

    private function cancelPendingClick() as Void {
        _pendingClickId = null;
        _clickDebounce.cancel();
    }

    private function persistVisibility() as Void {
        _hasVisibilityChanged = true;
        VisibilityStore.setHiddenFloors(_haState.getHiddenFloors());
        VisibilityStore.setHiddenAreas(_haState.getHiddenAreas());
        VisibilityStore.setIncludedLabels(_haState.getIncludedLabels());
    }
}
