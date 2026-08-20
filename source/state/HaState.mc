import Toybox.Lang;

// Everything the app knows about the home: what Home Assistant reported, indexed
// by the questions the screens ask of it. Each light carries its own assumed
// state; see LightModel for how a tap and a refresh interact.
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

    // A refresh replaces server truth wholesale, so a tap still awaiting its reply
    // is carried onto the incoming model. An assumption whose light is gone goes
    // with it.
    function setLights(lights as Dictionary<String, LightModel>) as Void {
        var previous = _lights.values() as Array<LightModel>;

        for (var index = 0; index < previous.size(); index++) {
            if (previous[index].assumed == null) {
                continue;
            }

            var incoming = lights.get(previous[index].id);
            if (incoming != null) {
                (incoming as LightModel).assumed = previous[index].assumed;
            }
        }

        _lights = lights;
        _lightsByArea = groupLightsByArea(lights);
    }

    function setSensors(sensors as Dictionary<String, SensorModel>) as Void {
        _sensorsByArea = groupSensorsByArea(sensors);
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

    // Every area the floor lists, registered or not: the service call expands the
    // floor server-side, so a narrower scope would claim less than the action does.
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

    // An area id the floor still lists but the registry no longer knows is
    // skipped: the two arrive on the same target but a floor outliving its area
    // is Home Assistant's to report, not ours to render.
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

    function override(entityId as String, isOn as Boolean) as Array<String> {
        return overrideAll(getToggleTargets(entityId), isOn);
    }

    function overrideFloorLights(floorId as String, isOn as Boolean) as Array<String> {
        return overrideAll(toLightIds(getLightsInFloor(floorId)), isOn);
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

    // Finding no assumption is a no-op: a refresh may have dropped an orphan whose
    // reply then arrives.
    function clearOverrides(entityIds as Array<String>) as Void {
        for (var index = 0; index < entityIds.size(); index++) {
            var light = _lights.get(entityIds[index]);

            if (light != null) {
                (light as LightModel).assumed = null;
            }
        }
    }

    private function overrideAll(entityIds as Array<String>, isOn as Boolean) as Array<String> {
        var overridden = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            var light = _lights.get(entityIds[index]);

            if (light != null) {
                (light as LightModel).assumed = isOn;
            }

            overridden.add(entityIds[index]);
        }

        return overridden;
    }

    private function groupLightsByArea(lights as Dictionary<String, LightModel>)
            as Dictionary<String, Array<LightModel>> {
        var byArea = {} as Dictionary<String, Array<LightModel>>;
        var models = lights.values() as Array<LightModel>;

        for (var index = 0; index < models.size(); index++) {
            var areaId = models[index].areaId;

            if (areaId != null) {
                var inArea = byArea.get(areaId);
                if (inArea == null) {
                    inArea = [] as Array<LightModel>;
                    byArea.put(areaId, inArea);
                }
                inArea.add(models[index]);
            }
        }

        return byArea;
    }

    private function groupSensorsByArea(sensors as Dictionary<String, SensorModel>)
            as Dictionary<String, Array<SensorModel>> {
        var byArea = {} as Dictionary<String, Array<SensorModel>>;
        var models = sensors.values() as Array<SensorModel>;

        for (var index = 0; index < models.size(); index++) {
            var areaId = models[index].areaId;

            if (areaId != null) {
                var inArea = byArea.get(areaId);
                if (inArea == null) {
                    inArea = [] as Array<SensorModel>;
                    byArea.put(areaId, inArea);
                }
                inArea.add(models[index]);
            }
        }

        return byArea;
    }
}
