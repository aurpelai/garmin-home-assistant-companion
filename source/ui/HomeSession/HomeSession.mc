import Toybox.Lang;

// Shared UI-side state passed between the area and entity menus: the HA client,
// the immutable server-truth HomeState (areas + loaded states), and a mutable
// copy of the states map. Toggles update the mutable copy optimistically so the
// switch flips immediately, leaving the HomeState as the untouched server truth.
class HomeSession {
    typedef LightStates as {
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
    private var _states as Dictionary<String, Boolean>;   // entity_id -> isOn, mutable

    function initialize(client as HaClient, state as HomeState) {
        self.client = client;
        _state = state;
        // Copy the loaded states so optimistic toggles never mutate the
        // HomeState (which stays immutable server-truth).
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

    // HA's display name for an entity (bare id as last-resort fallback).
    function getName(entityId as String) as String {
        return _state.getName(entityId);
    }

    // A sensor's HA-formatted value, null when the server sent none. Server truth
    // only, like availability, so it reads straight from the HomeState.
    function getReading(entityId as String) as String or Null {
        return _state.getReading(entityId);
    }

    // A sensor's numeric value, null when the server sent none. Server truth
    // only, like availability, so it reads straight from the HomeState.
    function getReadingValue(entityId as String) as Float or Null {
        return _state.getReadingValue(entityId);
    }

    // A sensor's unit of measurement, null when the server sent none. Server truth
    // only, like availability, so it reads straight from the HomeState.
    function getReadingUnit(entityId as String) as String or Null {
        return _state.getReadingUnit(entityId);
    }

    // A sensor's device_class, null when the payload carries none for the id.
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

    // An entity absent from the live state map reads as off.
    function isOn(entityId as String) as Boolean {
        var state = _states.get(entityId);
        return state == null
            ? false
            : state as Boolean;
    }

    // Availability is server truth only, never optimistically mutated, so it
    // reads straight from the HomeState rather than the mutable copy.
    function isAvailable(entityId as String) as Boolean {
        return _state.isAvailable(entityId);
    }

    // Tallies physical lights. Availability is server truth; on is counted
    // only among available lights.
    function getLightStates(lights as Array<String>) as LightStates {
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

    function getFloorLightStates(areaIds as Array<String>) as LightStates {
        var onCount = 0;
        var availableCount = 0;
        var unavailableCount = 0;

        for (var i = 0; i < areaIds.size(); i++) {
            var states = getLightStates(listLightsInArea(areaIds[i]));
            onCount += states.get(:on) as Number;
            availableCount += states.get(:available) as Number;
            unavailableCount += states.get(:unavailable) as Number;
        }

        return {
            :on => onCount,
            :available => availableCount,
            :unavailable => unavailableCount
        };
    }

    // Whether the live state map tracks this entity at all — for callers that
    // need to distinguish absent from present-but-off, which isOn's off default
    // cannot.
    function isTracked(entityId as String) as Boolean {
        return _states.hasKey(entityId);
    }

    // Flip local state and fire the toggle. The result callback reverts the
    // optimistic flip on failure.
    function toggleState(entityId as String, onComplete as Method) as Void {
        var newOn = !isOn(entityId);
        _states.put(entityId, newOn);
        client.toggleLight(entityId,
            new ToggleResultHandler(self, entityId, newOn, onComplete).method(:onResult));
    }

    function revertState(entityId as String, attemptedOn as Boolean) as Void {
        _states.put(entityId, !attemptedOn);
    }

    // Any available, physical light in the floor being on drives both the
    // any-on -> off toggle decision and the floor card's status.
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
        var newOn = !areFloorLightsOn(floorId);
        var lights = toggleableFloorLights(floorId);
        var priorOn = {} as Dictionary<String, Boolean>;

        for (var i = 0; i < lights.size(); i++) {
            var entityId = lights[i];
            priorOn.put(entityId, isOn(entityId));
            _states.put(entityId, newOn);
        }

        var service = newOn ? "turn_on" : "turn_off";
        client.toggleFloorLights(floorId, service,
            new FloorToggleResultHandler(self, priorOn, onComplete).method(:onResult));
    }

    function revertStates(priorOn as Dictionary<String, Boolean>) as Void {
        var entityIds = priorOn.keys();

        for (var i = 0; i < entityIds.size(); i++) {
            var entityId = entityIds[i];
            _states.put(entityId, priorOn.get(entityId) as Boolean);
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

    // Re-sync from a freshly fetched HomeState (most-recent-fetch wins). The
    // new state becomes the server truth backing structural reads on the next
    // menu construction; the live on/off map converges to it now.
    //
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

    // The single silent-convergence path for {action-completion, navigation,
    // resume}: fetch fresh state, apply it, then invoke onDone. A fetch
    // failure is swallowed (last-known state stays and heals on the next
    // trigger), yet onDone still fires so callers need no error branch.
    function refreshState(onDone as Method) as Void {
        client.fetchHomeState(new RefreshHandler(self, onDone).method(:onFetched));
    }
}
