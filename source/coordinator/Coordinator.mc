import Toybox.Lang;
import Toybox.WatchUi;

class Coordinator {
    private const STALE_AFTER_MS = 60 * 1000;
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
    }

    function onActivate() as Void {
        refresh();
    }

    function onViewShown(view as Screen) as Void {
        _currentView = view;
        updateDisplay();

        var age = _client.msSinceLastRefresh();
        if (_hasVisibilityChanged || age == null || age > STALE_AFTER_MS) {
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
                VisibilityStore.setVisibleAreaIds(_haState.getVisibleAreaIds());
            } else if (target == FetchTarget.LIGHTS) {
                _haState.setToggleables(Domain.LIGHT, HaPayload.parseLights(result));
                GlanceSummary.setLightSummary(HaPayload.parseHomeLightSummary(result));
            } else if (target == FetchTarget.FANS) {
                _haState.setToggleables(Domain.FAN, HaPayload.parseFans(result));
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

    function buildSettingsMenu() as [WatchUi.Views, WatchUi.InputDelegates] {
        return [new SettingsMenu(_haState), new SettingsMenuDelegate(self)];
    }

    function showVisibilityFilter() as Void {
        if (!_haState.hasAreas()) {
            return;
        }

        WatchUi.pushView(new VisibilityFilterMenu(), new VisibilityFilterDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function showFloorVisibility() as Void {
        var menu = new VisibilityToggleMenu(WatchUi.loadResource(Rez.Strings.SettingsFloors) as String,
            VisibilityMenuBuilder.buildFloorToggleRows(_haState));
        WatchUi.pushView(menu, new VisibilityToggleDelegate(method(:setFloorHidden)), WatchUi.SLIDE_LEFT);
    }

    function showAreaVisibility() as Void {
        var rows = VisibilityMenuBuilder.buildAreaVisibilityRows(
            _haState, WatchUi.loadResource(Rez.Strings.SettingsOtherAreas) as String);
        WatchUi.pushView(new AreaVisibilityMenu(rows), new AreaVisibilityDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function showFloorAreaVisibility(floorId as String) as Void {
        var floor = _haState.getFloor(floorId);
        if (floor == null) {
            return;
        }

        showAreaToggles(floor.name, _haState.getAreasInFloor(floorId));
    }

    function showUnflooredAreaVisibility() as Void {
        showAreaToggles(WatchUi.loadResource(Rez.Strings.SettingsOtherAreas) as String, _haState.getUnflooredAreas());
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
            openAttributeMenu(entityId);
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

    function setFloorHidden(floorId as String, isHidden as Boolean) as Void {
        _haState.setFloorHidden(floorId, isHidden);
        persistVisibility();
    }

    function setAreaHidden(areaId as String, isHidden as Boolean) as Void {
        _haState.setAreaHidden(areaId, isHidden);
        persistVisibility();
    }

    function setAttribute(attribute as AdjustableAttribute, value as Number) as Void {
        commitAttribute(attribute, attribute.resolveService(value), value);
    }

    function toggleAttribute(attribute as AdjustableAttribute, isOn as Boolean) as Void {
        commitAttribute(attribute, attribute.service, isOn);
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
        var lights = _haState.getToggleablesInFloor(floorId, Domain.LIGHT);
        if (lights.size() == 0 || _haState.hasAnyPending(_haState.toIds(lights))) {
            return;
        }

        var targetState = !_haState.hasAnyOn(lights);
        _haState.overrideFloorLights(floorId, targetState);
        var service = targetState ? "turn_on" : "turn_off";

        _client.queueLightsInAreas(_haState.getVisibleAreaIdsInFloor(floorId), service,
            new ToggleReply(self).method(:onSettled));
        updateDisplay();
    }

    // The state is emptied here, so whatever is on screen would draw a home with
    // nothing in it until the refresh settles.
    function discardRegistration() as Void {
        _client.cancelAll();
        _client.discardRegistration();
        _haState.clear();
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
        _haState.assumeAttribute(attribute.entityId, attribute.field, value);
        _client.queueAttribute(attribute.domain, service, attribute.entityId,
            attribute.field, value, new ToggleReply(self).method(:onSettled));
        updateDisplay();
    }

    private function openAttributeMenu(entityId as String) as Void {
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
        VisibilityStore.setVisibleAreaIds(_haState.getVisibleAreaIds());
    }

    private function showAreaToggles(title as String, areas as Array<AreaModel>) as Void {
        var menu = new VisibilityToggleMenu(title, VisibilityMenuBuilder.buildAreaToggleRows(_haState, areas));
        WatchUi.pushView(menu, new VisibilityToggleDelegate(method(:setAreaHidden)), WatchUi.SLIDE_LEFT);
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
