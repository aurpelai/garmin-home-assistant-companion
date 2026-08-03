import Toybox.Lang;

// Toggles update the mutable copy optimistically so the switch flips
// immediately, leaving the HomeState as the untouched server truth.
class HomeSession {
    typedef LightSummary as {
        :on as Number,
        :available as Number,
        :unavailable as Number
    };

    typedef SensorReading as {
        :device_class as String,
        :value as Float,
        :unit as String or Null,
        :display as String
    };

    public var client as HaClient;
    private var _state as HomeState;
    // A light's on/off, the Boolean projection of HA's richer state string —
    // all we need to drive a toggle. Availability is a separate axis (see
    // isAvailable), never encoded here.
    private var _states as Dictionary<String, Boolean>;

    function initialize(client as HaClient, state as HomeState) {
        self.client = client;
        _state = state;
        var copy = {} as Dictionary<String, Boolean>;
        var entityIds = state.lightIds();
        for (var i = 0; i < entityIds.size(); i++) {
            copy.put(entityIds[i], state.isOn(entityIds[i]));
        }
        self._states = copy;
    }

    function listLightsInArea(areaId as String) as Array<String> {
        return _state.listLightsInArea(areaId);
    }

    function listLightsInFloor(floorId as String) as Array<String> {
        return _state.listLightsInFloor(floorId);
    }

    function listSensorsInArea(areaId as String) as Array<String> {
        return _state.listSensorsInArea(areaId);
    }

    function getAreaName(areaId as String) as String {
        return _state.getAreaName(areaId);
    }

    function getName(entityId as String) as String {
        return _state.getName(entityId);
    }

    function getReading(entityId as String) as String or Null {
        return _state.getReading(entityId);
    }

    function getReadingValue(entityId as String) as Float or Null {
        return _state.getReadingValue(entityId);
    }

    function getReadingUnit(entityId as String) as String or Null {
        return _state.getReadingUnit(entityId);
    }

    function getDeviceClass(entityId as String) as String or Null {
        return _state.getDeviceClass(entityId);
    }

    function buildFloors() as Array<Dictionary> {
        return _state.buildFloors();
    }

    function isGroup(entityId as String) as Boolean {
        return _state.isGroup(entityId);
    }

    function getMemberCount(entityId as String) as Number {
        return _state.getMemberCount(entityId);
    }

    function isOn(entityId as String) as Boolean {
        return _states.hasKey(entityId)
            ? _states.get(entityId) as Boolean
            : false;
    }

    // Availability is server truth only, never optimistically mutated, so it
    // reads straight from the HomeState rather than the mutable copy.
    function isAvailable(entityId as String) as Boolean {
        return _state.isAvailable(entityId);
    }

    // Tallies physical lights. On is counted only among available lights.
    function getLightSummary(lights as Array<String>) as LightSummary {
        var onCount = 0;
        var availableCount = 0;
        var unavailableCount = 0;

        for (var i = 0; i < lights.size(); i++) {
            var light = lights[i];

            if (isGroup(light)) {
                continue;
            }

            if (isAvailable(light)) {
                availableCount++;

                if (isOn(light)) {
                    onCount++;
                }
            } else {
                unavailableCount++;
            }
        }

        return {
            :on => onCount,
            :available => availableCount,
            :unavailable => unavailableCount
        };
    }

    function getAreaReadings(areaId as String) as Array<SensorReading> {
        var sensors = listSensorsInArea(areaId);
        var readings = [] as Array<SensorReading>;

        for (var i = 0; i < sensors.size(); i++) {
            var entityId = sensors[i];
            var deviceClass = getDeviceClass(entityId);
            var value = getReadingValue(entityId);
            var display = getReading(entityId);

            if (deviceClass == null || value == null || display == null) {
                continue;
            }

            readings.add({
                :device_class => deviceClass,
                :value => value,
                :unit => getReadingUnit(entityId),
                :display => display
            });
        }

        return readings;
    }

    function getFloorReadings(areaIds as Array<String>) as Array<SensorReading> {
        var readings = [] as Array<SensorReading>;

        for (var i = 0; i < areaIds.size(); i++) {
            readings.addAll(getAreaReadings(areaIds[i]));
        }

        return readings;
    }

    function getFloorLightSummary(areaIds as Array<String>) as LightSummary {
        var onCount = 0;
        var availableCount = 0;
        var unavailableCount = 0;

        for (var i = 0; i < areaIds.size(); i++) {
            var summary = getLightSummary(listLightsInArea(areaIds[i]));
            onCount += summary.get(:on) as Number;
            availableCount += summary.get(:available) as Number;
            unavailableCount += summary.get(:unavailable) as Number;
        }

        return {
            :on => onCount,
            :available => availableCount,
            :unavailable => unavailableCount
        };
    }

    // Distinguishes absent from present-but-off, which isOn's off default cannot.
    function isTracked(entityId as String) as Boolean {
        return _states.hasKey(entityId);
    }

    function toggleState(entityId as String, onComplete as Method) as Void {
        var savedState = isOn(entityId);
        _states.put(entityId, !savedState);
        client.toggleLight(entityId,
            new PendingToggle(self, entityId, savedState, onComplete).method(:onResult));
    }

    function revertToggle(entityId as String, savedState as Boolean) as Void {
        _states.put(entityId, savedState);
    }

    // Any available, physical light in the floor being on.
    function areFloorLightsOn(floorId as String) as Boolean {
        var lights = toggleableFloorLights(floorId);

        for (var i = 0; i < lights.size(); i++) {
            if (isOn(lights[i])) {
                return true;
            }
        }

        return false;
    }

    // Direction is decided once from any-on so the whole floor lands in one
    // state. Each affected light's prior value is captured before the optimistic
    // flip, so a failed call restores exactly those, not a blanket flip.
    function toggleFloorLights(floorId as String, onComplete as Method) as Void {
        var targetState = !areFloorLightsOn(floorId);
        var lights = toggleableFloorLights(floorId);
        var savedStates = {} as Dictionary<String, Boolean>;

        for (var i = 0; i < lights.size(); i++) {
            var entityId = lights[i];
            savedStates.put(entityId, isOn(entityId));
            _states.put(entityId, targetState);
        }

        var service = targetState ? "turn_on" : "turn_off";
        client.toggleFloorLights(floorId, service,
            new PendingWholeFloorToggle(self, savedStates, onComplete).method(:onResult));
    }

    function revertStates(savedStates as Dictionary<String, Boolean>) as Void {
        var entityIds = savedStates.keys();

        for (var i = 0; i < entityIds.size(); i++) {
            var entityId = entityIds[i];
            _states.put(entityId, savedStates.get(entityId) as Boolean);
        }
    }

    private function toggleableFloorLights(floorId as String) as Array<String> {
        var lights = listLightsInFloor(floorId);
        var toggleable = [] as Array<String>;

        for (var i = 0; i < lights.size(); i++) {
            var entityId = lights[i];
            if (!isGroup(entityId) && isAvailable(entityId)) {
                toggleable.add(entityId);
            }
        }

        return toggleable;
    }

    // Only entities already present in the live map are updated, and only when
    // the fresh state actually knows them — a state that omits an entity leaves
    // its value alone rather than reading the isOn default and flipping it off.
    // Keys are never added or dropped here: structural drift (entities or group
    // membership appearing/disappearing) is deferred to the next navigation.
    function applyState(state as HomeState) as Void {
        _state = state;

        var entityIds = _states.keys();
        for (var i = 0; i < entityIds.size(); i++) {
            var entityId = entityIds[i];
            if (state.hasLight(entityId)) {
                _states.put(entityId, state.isOn(entityId));
            }
        }
    }

    // A fetch failure is swallowed (last-known state stays and heals on the next
    // trigger), yet onDone still fires so callers need no error branch.
    function refreshState(onDone as Method) as Void {
        client.fetchHomeState(new PendingRefresh(self, onDone).method(:onFetched));
    }
}
