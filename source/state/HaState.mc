import Toybox.Lang;

class HaState {
    private var _toggleablesByDomain as Dictionary<String, Dictionary<String, ToggleableModel>>;
    private var _toggleablesByDomainAndArea as Dictionary<String, Dictionary<String, Array<ToggleableModel>>>;
    private var _areas as Dictionary<String, AreaModel>;
    private var _floors as Array<FloorModel>;
    private var _sensorsByArea as Dictionary<String, Array<SensorModel>>;
    private var _zone as String or Null;
    private var _sensorAverages as SensorAverages;

    // Durable user config, not fetched truth: the hidden sets survive clear() so a
    // registration discard never silently unhides the home.
    private var _hiddenFloors as Dictionary<String, Boolean>;
    private var _hiddenAreas as Dictionary<String, Boolean>;

    function initialize() {
        _toggleablesByDomain = {};
        _toggleablesByDomainAndArea = {};
        _areas = {};
        _floors = [];
        _sensorsByArea = {};
        _zone = null;
        _sensorAverages = new SensorAverages();
        _hiddenFloors = {};
        _hiddenAreas = {};
    }

    function clear() as Void {
        _toggleablesByDomain = {};
        _toggleablesByDomainAndArea = {};
        _areas = {};
        _floors = [];
        _sensorsByArea = {};
        _zone = null;
        _sensorAverages = new SensorAverages();
    }

    function setHidden(hiddenFloors as Dictionary<String, Boolean>,
                       hiddenAreas as Dictionary<String, Boolean>) as Void {
        _hiddenFloors = hiddenFloors;
        _hiddenAreas = hiddenAreas;
    }

    function setFloorHidden(floorId as String, isHidden as Boolean) as Void {
        setMembership(_hiddenFloors, floorId, isHidden);
    }

    function setAreaHidden(areaId as String, isHidden as Boolean) as Void {
        setMembership(_hiddenAreas, areaId, isHidden);
    }

    function setZone(zone as String or Null) as Void {
        _zone = zone;
    }

    function setAreas(areas as Dictionary<String, AreaModel>) as Void {
        _areas = areas;
    }

    function setFloors(floors as Array<FloorModel>) as Void {
        _floors = floors;
    }

    // A fetch clears pending overrides only by replacing the models wholesale;
    // the fresh ones come back with no assumption. Updating them in place instead
    // would leave a tapped entity pending forever.
    function setToggleables(domain as String, toggleables as Dictionary<String, ToggleableModel>) as Void {
        _toggleablesByDomain.put(domain, toggleables);
        _toggleablesByDomainAndArea.put(domain,
            groupByArea(toggleables.values() as Array<EntityModel>) as Dictionary<String, Array<ToggleableModel>>);
    }

    function setSensors(sensors as Dictionary<String, SensorModel>) as Void {
        _sensorsByArea = groupByArea(sensors.values() as Array<EntityModel>) as Dictionary<String, Array<SensorModel>>;
    }

    function setSensorAverages(areaAverages as Dictionary<String, Dictionary<String, String>>,
                               floorAverages as Dictionary<String, Dictionary<String, String>>) as Void {
        _sensorAverages.set(areaAverages, floorAverages);
    }

    function getAreaSensorAverages(areaId as String) as Dictionary<String, String> {
        return _sensorAverages.getArea(areaId);
    }

    function getFloorSensorAverages(floorId as String) as Dictionary<String, String> {
        return _sensorAverages.getFloor(floorId);
    }

    function getArea(areaId as String) as AreaModel or Null {
        return _areas.get(areaId);
    }

    function getAreas() as Array<AreaModel> {
        return _areas.values() as Array<AreaModel>;
    }

    function getFloors() as Array<FloorModel> {
        return _floors;
    }

    function getFloor(floorId as String) as FloorModel or Null {
        for (var index = 0; index < _floors.size(); index++) {
            if (_floors[index].id.equals(floorId)) {
                return _floors[index];
            }
        }

        return null;
    }

    function getZone() as String or Null {
        return _zone;
    }

    function getToggleable(entityId as String) as ToggleableModel or Null {
        var byId = _toggleablesByDomain.get(Entity.resolveDomain(entityId));
        return byId == null ? null : byId.get(entityId);
    }

    function getToggleablesInArea(areaId as String, domain as String) as Array<ToggleableModel> {
        var byArea = _toggleablesByDomainAndArea.get(domain);
        var toggleables = byArea == null ? null : byArea.get(areaId);
        return toggleables == null ? [] as Array<ToggleableModel> : toggleables;
    }

    function getSensorsInArea(areaId as String) as Array<SensorModel> {
        var sensors = _sensorsByArea.get(areaId);
        return sensors == null ? [] as Array<SensorModel> : sensors;
    }

    // Visible areas only: a hidden area is not part of the home the app reads or
    // acts on, so its toggleables leave both the floor summary and the floor-wide
    // action.
    function getToggleablesInFloor(floorId as String, domain as String) as Array<ToggleableModel> {
        var areaIds = getVisibleAreaIdsInFloor(floorId);
        var toggleables = [] as Array<ToggleableModel>;

        for (var index = 0; index < areaIds.size(); index++) {
            toggleables.addAll(getToggleablesInArea(areaIds[index], domain));
        }

        return toggleables;
    }

    function getAreasInFloor(floorId as String) as Array<AreaModel> {
        var floor = getFloor(floorId);
        return floor == null ? [] as Array<AreaModel> : resolveAreas(floor.areas);
    }

    function getVisibleAreasInFloor(floorId as String) as Array<AreaModel> {
        return resolveAreas(getVisibleAreaIdsInFloor(floorId));
    }

    function getVisibleAreaIdsInFloor(floorId as String) as Array<String> {
        var floor = getFloor(floorId);
        return floor == null
            ? [] as Array<String>
            : AreaVisibility.visibleAreasOfFloor(floor, _hiddenFloors, _hiddenAreas);
    }

    function getUnflooredAreas() as Array<AreaModel> {
        var floored = collectFlooredAreaIds();
        var areas = getAreas();
        var unfloored = [] as Array<AreaModel>;

        for (var index = 0; index < areas.size(); index++) {
            if (!floored.hasKey(areas[index].id)) {
                unfloored.add(areas[index]);
            }
        }

        return unfloored;
    }

    function getVisibleUnflooredAreas() as Array<AreaModel> {
        var unfloored = getUnflooredAreas();
        var visible = [] as Array<AreaModel>;

        for (var index = 0; index < unfloored.size(); index++) {
            if (!_hiddenAreas.hasKey(unfloored[index].id)) {
                visible.add(unfloored[index]);
            }
        }

        return visible;
    }

    function getVisibleAreaIds() as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < _floors.size(); index++) {
            ids.addAll(getVisibleAreaIdsInFloor(_floors[index].id));
        }

        var unfloored = getVisibleUnflooredAreas();

        for (var index = 0; index < unfloored.size(); index++) {
            ids.add(unfloored[index].id);
        }

        return ids;
    }

    function getHiddenFloors() as Dictionary<String, Boolean> {
        return _hiddenFloors;
    }

    function getHiddenAreas() as Dictionary<String, Boolean> {
        return _hiddenAreas;
    }

    function getToggleTargets(entityId as String) as Array<String> {
        var toggleable = getToggleable(entityId);
        var memberIds = toggleable == null ? null : toggleable.memberIds;
        var targets = [entityId] as Array<String>;

        if (memberIds != null) {
            targets.addAll(memberIds);
        }

        return targets;
    }

    function hasAreas() as Boolean {
        return _areas.size() > 0;
    }

    function hasEntitiesInArea(areaId as String) as Boolean {
        if (getSensorsInArea(areaId).size() > 0) {
            return true;
        }

        var domains = _toggleablesByDomainAndArea.keys();

        for (var index = 0; index < domains.size(); index++) {
            if (getToggleablesInArea(areaId, domains[index] as String).size() > 0) {
                return true;
            }
        }

        return false;
    }

    function isFloorVisible(floorId as String) as Boolean {
        var floor = getFloor(floorId);
        return floor != null && AreaVisibility.isFloorVisible(floor, _hiddenFloors, _hiddenAreas);
    }

    function isOn(entityId as String) as Boolean {
        var toggleable = getToggleable(entityId);
        return toggleable != null && toggleable.isOn();
    }

    function isPending(entityId as String) as Boolean {
        var toggleable = getToggleable(entityId);
        return toggleable != null && toggleable.isPending();
    }

    function toIds(toggleables as Array<ToggleableModel>) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < toggleables.size(); index++) {
            ids.add(toggleables[index].id);
        }

        return ids;
    }

    function hasAnyOn(toggleables as Array<ToggleableModel>) as Boolean {
        for (var index = 0; index < toggleables.size(); index++) {
            if (toggleables[index].isOn()) {
                return true;
            }
        }

        return false;
    }

    function hasAnyPending(entityIds as Array<String>) as Boolean {
        for (var index = 0; index < entityIds.size(); index++) {
            if (isPending(entityIds[index])) {
                return true;
            }
        }

        return false;
    }

    function override(entityId as String, isOn as Boolean) as Void {
        overrideAll(getToggleTargets(entityId), isOn);
    }

    function overrideFloorLights(floorId as String, isOn as Boolean) as Void {
        overrideAll(toIds(getToggleablesInFloor(floorId, Domain.LIGHT)), isOn);
    }

    function assumeAttribute(entityId as String, field as String, value as Object) as Void {
        var toggleable = getToggleable(entityId);
        if (toggleable != null) {
            toggleable.assumeAttribute(field, value);
        }
    }

    private function overrideAll(entityIds as Array<String>, isOn as Boolean) as Void {
        for (var index = 0; index < entityIds.size(); index++) {
            var toggleable = getToggleable(entityIds[index]);

            if (toggleable != null) {
                toggleable.assumedState = isOn;
            }
        }
    }

    private function setMembership(set as Dictionary<String, Boolean>, id as String, isMember as Boolean) as Void {
        if (isMember) {
            set.put(id, true);
        } else {
            set.remove(id);
        }
    }

    private function resolveAreas(areaIds as Array<String>) as Array<AreaModel> {
        var areas = [] as Array<AreaModel>;

        for (var index = 0; index < areaIds.size(); index++) {
            var area = _areas.get(areaIds[index]);
            if (area != null) {
                areas.add(area);
            }
        }

        return areas;
    }

    private function collectFlooredAreaIds() as Dictionary<String, Boolean> {
        var floored = {} as Dictionary<String, Boolean>;

        for (var floorIndex = 0; floorIndex < _floors.size(); floorIndex++) {
            var areaIds = _floors[floorIndex].areas;

            for (var areaIndex = 0; areaIndex < areaIds.size(); areaIndex++) {
                floored.put(areaIds[areaIndex], true);
            }
        }

        return floored;
    }

    private function groupByArea(models as Array<EntityModel>)
            as Dictionary<String, Array<EntityModel>> {
        var byArea = {} as Dictionary<String, Array<EntityModel>>;

        for (var index = 0; index < models.size(); index++) {
            var areaId = models[index].areaId;

            if (areaId != null) {
                var inArea = byArea.get(areaId);
                if (inArea == null) {
                    inArea = [] as Array<EntityModel>;
                    byArea.put(areaId, inArea);
                }
                inArea.add(models[index]);
            }
        }

        return byArea;
    }
}
