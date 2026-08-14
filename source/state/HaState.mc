import Toybox.Lang;

// What Home Assistant reported, plus the values the user's taps assumed. Server
// truth is never overwritten by a tap: an override sits over it, so reverting is
// deletion rather than restoration and a refresh is a plain replacement.
//
// Knows entities, not transport: HaPayload turns a payload into the shapes set
// here. Holds no client and knows nothing of views.
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

    // One setter per target, so a write covers exactly one target's worth of
    // state and a caller cannot pair a target with another's data.
    function setStructure(structure as ParsedStructure) as Void {
        _zone = structure.zone;
        _areas = structure.areas;
        _floors = structure.floors;
    }

    function setLights(parsed as ParsedLights) as Void {
        _lights = parsed.lights;
        _lightIdsByArea = parsed.lightIdsByArea;
        dropOrphanedOverrides();
    }

    function setSensors(parsed as ParsedSensors) as Void {
        _sensors = parsed.sensors;
        _sensorIdsByArea = parsed.sensorIdsByArea;
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

    function getZone() as String or Null {
        return _zone;
    }

    function getLightIdsInArea(areaId as String) as Array<String> {
        return idsInArea(_lightIdsByArea, areaId);
    }

    function getSensorIdsInArea(areaId as String) as Array<String> {
        return idsInArea(_sensorIdsByArea, areaId);
    }

    function getLightIdsInFloor(floorId as String) as Array<String> {
        var out = [] as Array<String>;
        var areaIds = areaIdsInFloor(floorId);

        for (var index = 0; index < areaIds.size(); index++) {
            out.addAll(getLightIdsInArea(areaIds[index]));
        }

        return out;
    }

    // Resolves rather than reads: the assumed value wins while one exists.
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
        return overrideAll(entityScope(entityId), isOn);
    }

    // Every light in the floor, groups and unavailable ones included: Home
    // Assistant expands the floor server-side and accepts a call to a light that
    // is currently unreachable, so anything narrower would model a smaller scope
    // than the action actually has.
    function overrideFloorLights(floorId as String, isOn as Boolean) as Array<String> {
        return overrideAll(getLightIdsInFloor(floorId), isOn);
    }

    // What a toggle of this entity covers: itself and, when it is a group,
    // everything it stands for. A group needs both — its own row is the one the
    // user tapped, and its members are the rows beneath it, so moving either alone
    // leaves the menu half-updated.
    //
    // The members are the group's own, as the payload reported them — a display
    // claim, not a correctness claim: Home Assistant's own expansion can differ,
    // and the refresh after the reply is what makes them converge.
    function entityScope(entityId as String) as Array<String> {
        var light = _lights.get(entityId);
        var memberIds = light == null ? null : light.memberIds;
        var scope = [entityId] as Array<String>;

        if (memberIds != null) {
            scope.addAll(memberIds);
        }

        return scope;
    }

    // Both resolve over a scope, so a floor's own row, the direction its tap picks
    // and the guard that refuses a second tap all read the same two questions.
    function anyOn(entityIds as Array<String>) as Boolean {
        for (var index = 0; index < entityIds.size(); index++) {
            if (isOn(entityIds[index])) {
                return true;
            }
        }

        return false;
    }

    function anyPending(entityIds as Array<String>) as Boolean {
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

    // Returns its own array rather than the one passed in, so what the caller
    // holds onto can never alias anything HaState reads back.
    private function overrideAll(entityIds as Array<String>, isOn as Boolean) as Array<String> {
        var overridden = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            _overrides.put(entityIds[index], isOn);
            overridden.add(entityIds[index]);
        }

        return overridden;
    }

    private function areaIdsInFloor(floorId as String) as Array<String> {
        for (var index = 0; index < _floors.size(); index++) {
            if (_floors[index].id.equals(floorId)) {
                return _floors[index].areas;
            }
        }

        return [] as Array<String>;
    }

    private function idsInArea(idsByArea as Dictionary<String, Array<String>>,
                               areaId as String) as Array<String> {
        var ids = idsByArea.get(areaId);
        return ids == null ? [] as Array<String> : ids;
    }

    // A refresh sets fresh server truth and clears nothing, so an override
    // outlives it — unless its entity is gone, which leaves the entry with
    // nothing to sit over.
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
