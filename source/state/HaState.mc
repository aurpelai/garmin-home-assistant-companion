import Toybox.Lang;

class HaState {
    private var _lights as Dictionary<String, LightModel>;
    private var _areas as Dictionary<String, AreaModel>;
    private var _floors as Array<FloorModel>;
    private var _lightsByArea as Dictionary<String, Array<LightModel>>;
    private var _sensorsByArea as Dictionary<String, Array<SensorModel>>;
    private var _zone as String or Null;

    function initialize() {
        _lights = {};
        _areas = {};
        _floors = [];
        _lightsByArea = {};
        _sensorsByArea = {};
        _zone = null;
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
    // would leave a tapped light pending forever.
    function setLights(lights as Dictionary<String, LightModel>) as Void {
        _lights = lights;
        _lightsByArea = groupByArea(lights.values() as Array<EntityModel>) as Dictionary<String, Array<LightModel>>;
    }

    function setSensors(sensors as Dictionary<String, SensorModel>) as Void {
        _sensorsByArea = groupByArea(sensors.values() as Array<EntityModel>) as Dictionary<String, Array<SensorModel>>;
    }

    function hasAreas() as Boolean {
        return _areas.size() > 0;
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

    function getLightsInArea(areaId as String) as Array<LightModel> {
        var lights = _lightsByArea.get(areaId);
        return lights == null ? [] as Array<LightModel> : lights;
    }

    function getSensorsInArea(areaId as String) as Array<SensorModel> {
        var sensors = _sensorsByArea.get(areaId);
        return sensors == null ? [] as Array<SensorModel> : sensors;
    }

    function getLightsInFloor(floorId as String) as Array<LightModel> {
        var floor = getFloor(floorId);
        var lights = [] as Array<LightModel>;

        if (floor == null) {
            return lights;
        }

        for (var index = 0; index < floor.areas.size(); index++) {
            lights.addAll(getLightsInArea(floor.areas[index]));
        }

        return lights;
    }

    function getAreasInFloor(floorId as String) as Array<AreaModel> {
        var floor = getFloor(floorId);
        var areas = [] as Array<AreaModel>;

        if (floor == null) {
            return areas;
        }

        for (var index = 0; index < floor.areas.size(); index++) {
            var area = _areas.get(floor.areas[index]);
            if (area != null) {
                areas.add(area);
            }
        }

        return areas;
    }

    function isOn(entityId as String) as Boolean {
        var light = _lights.get(entityId);
        return light != null && light.isOn();
    }

    function isPending(entityId as String) as Boolean {
        var light = _lights.get(entityId);
        return light != null && light.isPending();
    }

    function override(entityId as String, isOn as Boolean) as Void {
        overrideAll(getToggleTargets(entityId), isOn);
    }

    function overrideFloorLights(floorId as String, isOn as Boolean) as Void {
        overrideAll(toLightIds(getLightsInFloor(floorId)), isOn);
    }

    function getToggleTargets(entityId as String) as Array<String> {
        var light = _lights.get(entityId);
        var memberIds = light == null ? null : light.memberIds;
        var targets = [entityId] as Array<String>;

        if (memberIds != null) {
            targets.addAll(memberIds);
        }

        return targets;
    }

    function allLightsState() as Symbol or Null {
        var lights = _lights.values() as Array<LightModel>;
        if (lights.size() == 0) {
            return null;
        }

        var onCount = 0;
        for (var index = 0; index < lights.size(); index++) {
            if (lights[index].isOn()) {
                onCount++;
            }
        }

        if (onCount == 0) {
            return :allOff;
        }

        return onCount == lights.size() ? :allOn : :someOn;
    }

    function hasAnyOn(lights as Array<LightModel>) as Boolean {
        for (var index = 0; index < lights.size(); index++) {
            if (lights[index].isOn()) {
                return true;
            }
        }

        return false;
    }

    function toLightIds(lights as Array<LightModel>) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < lights.size(); index++) {
            ids.add(lights[index].id);
        }

        return ids;
    }

    function hasAnyPending(entityIds as Array<String>) as Boolean {
        for (var index = 0; index < entityIds.size(); index++) {
            if (isPending(entityIds[index])) {
                return true;
            }
        }

        return false;
    }

    private function overrideAll(entityIds as Array<String>, isOn as Boolean) as Void {
        for (var index = 0; index < entityIds.size(); index++) {
            var light = _lights.get(entityIds[index]);

            if (light != null) {
                (light as LightModel).assumed = isOn;
            }
        }
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
