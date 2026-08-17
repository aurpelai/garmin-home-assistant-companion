import Toybox.Lang;

// What Home Assistant reported, plus the values the user's taps assumed. Server
// truth is never overwritten by a tap: an override sits over it, so reverting is
// deletion rather than restoration and a refresh is a plain replacement.
class HaState {
    private var _lights as Dictionary<String, LightModel>;
    private var _sensors as Dictionary<String, SensorModel>;
    private var _areas as Dictionary<String, AreaModel>;
    private var _floors as Array<FloorModel>;
    private var _lightIdsByArea as Dictionary<String, Array<String>>;
    private var _sensorIdsByArea as Dictionary<String, Array<String>>;
    private var _zone as String or Null;
    private var _overrides as Dictionary<String, Boolean>;

    function initialize() {
        _lights = {};
        _sensors = {};
        _areas = {};
        _floors = [];
        _lightIdsByArea = {};
        _sensorIdsByArea = {};
        _zone = null;
        _overrides = {};
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

    function setLights(lights as Dictionary<String, LightModel>) as Void {
        _lights = lights;
        _lightIdsByArea = groupLightIdsByArea(lights);
        dropOrphanedOverrides();
    }

    function setSensors(sensors as Dictionary<String, SensorModel>) as Void {
        _sensors = sensors;
        _sensorIdsByArea = groupSensorIdsByArea(sensors);
    }

    function hasAreas() as Boolean {
        return _areas.size() > 0;
    }

    function getLight(entityId as String) as LightModel or Null {
        return _lights.get(entityId);
    }

    function getSensor(entityId as String) as SensorModel or Null {
        return _sensors.get(entityId);
    }

    function getArea(areaId as String) as AreaModel or Null {
        return _areas.get(areaId);
    }

    function getAreaIds() as Array<String> {
        return _areas.keys() as Array<String>;
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

    function getLightIdsInArea(areaId as String) as Array<String> {
        var lightIds = _lightIdsByArea.get(areaId);
        return lightIds == null ? [] as Array<String> : lightIds;
    }

    function getSensorIdsInArea(areaId as String) as Array<String> {
        var sensorIds = _sensorIdsByArea.get(areaId);
        return sensorIds == null ? [] as Array<String> : sensorIds;
    }

    function getLightIdsInFloor(floorId as String) as Array<String> {
        var floor = getFloor(floorId);
        var lightIds = [] as Array<String>;

        if (floor == null) {
            return lightIds;
        }

        for (var index = 0; index < floor.areas.size(); index++) {
            lightIds.addAll(getLightIdsInArea(floor.areas[index]));
        }

        return lightIds;
    }

    function isOn(entityId as String) as Boolean {
        var assumed = _overrides.get(entityId);
        if (assumed != null) {
            return assumed;
        }

        var light = _lights.get(entityId);
        return light != null && light.state;
    }

    function isPending(entityId as String) as Boolean {
        return _overrides.hasKey(entityId);
    }

    function override(entityId as String, isOn as Boolean) as Array<String> {
        return overrideAll(getToggleTargets(entityId), isOn);
    }

    function overrideFloorLights(floorId as String, isOn as Boolean) as Array<String> {
        return overrideAll(getLightIdsInFloor(floorId), isOn);
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

    function hasAnyOn(entityIds as Array<String>) as Boolean {
        for (var index = 0; index < entityIds.size(); index++) {
            if (isOn(entityIds[index])) {
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

    // Finding no override is a no-op: a refresh may have dropped an orphan whose
    // reply then arrives.
    function clearOverrides(entityIds as Array<String>) as Void {
        for (var index = 0; index < entityIds.size(); index++) {
            _overrides.remove(entityIds[index]);
        }
    }

    private function overrideAll(entityIds as Array<String>, isOn as Boolean) as Array<String> {
        var overridden = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            _overrides.put(entityIds[index], isOn);
            overridden.add(entityIds[index]);
        }

        return overridden;
    }

    private function groupLightIdsByArea(lights as Dictionary<String, LightModel>)
            as Dictionary<String, Array<String>> {
        var idsByArea = {} as Dictionary<String, Array<String>>;
        var entityIds = lights.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var areaId = (lights.get(entityId) as LightModel).areaId;

            if (areaId != null) {
                var inArea = idsByArea.get(areaId);
                if (inArea == null) {
                    inArea = [] as Array<String>;
                    idsByArea.put(areaId, inArea);
                }
                inArea.add(entityId);
            }
        }

        return idsByArea;
    }

    private function groupSensorIdsByArea(sensors as Dictionary<String, SensorModel>)
            as Dictionary<String, Array<String>> {
        var idsByArea = {} as Dictionary<String, Array<String>>;
        var entityIds = sensors.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var areaId = (sensors.get(entityId) as SensorModel).areaId;

            if (areaId != null) {
                var inArea = idsByArea.get(areaId);
                if (inArea == null) {
                    inArea = [] as Array<String>;
                    idsByArea.put(areaId, inArea);
                }
                inArea.add(entityId);
            }
        }

        return idsByArea;
    }

    private function dropOrphanedOverrides() as Void {
        var entityIds = _overrides.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            if (!isKnownEntity(entityId)) {
                _overrides.remove(entityId);
            }
        }
    }

    // Every overridable domain must be asked, or the domain that is missing here
    // loses its overrides on every other domain's refresh.
    private function isKnownEntity(entityId as String) as Boolean {
        return _lights.hasKey(entityId);
    }
}
