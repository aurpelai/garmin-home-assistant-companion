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
        :kind as String,
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
        var entityIds = state.states.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            copy.put(entityIds[index], state.isOn(entityIds[index]));
        }
        self._states = copy;
    }

    // Area-structure reads delegate to the HomeState so menus don't reach into it.
    function areas() as Array<Dictionary> {
        return _state.areas;
    }

    function listLightsInArea(name as String) as Array<String> {
        return _state.listLightsInArea(name);
    }

    function listSensorsInArea(name as String) as Array<String> {
        return _state.listSensorsInArea(name);
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

    // A sensor's device_class, null when the payload carries no kind for the id.
    function getKind(entityId as String) as String or Null {
        return _state.getKind(entityId);
    }

    function buildFloorGroups() as Array<Dictionary> {
        return _state.buildFloorGroups();
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

    // Tallies lights, skipping group entities — HA marks a group on when any
    // member is on, so counting groups would double-count. Availability is
    // server truth; on is counted only among available lights.
    function getLightStates(lights as Array<String>) as LightStates {
        var onCount = 0;
        var availableCount = 0;
        var unavailableCount = 0;

        for (var index = 0; index < lights.size(); index++) {
            var light = lights[index];

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

    function getAreaReadings(name as String) as Array<SensorReading> {
        var sensors = listSensorsInArea(name);
        var readings = [] as Array<SensorReading>;

        for (var index = 0; index < sensors.size(); index++) {
            var entityId = sensors[index];
            var kind = getKind(entityId);
            var value = getReadingValue(entityId);
            var display = getReading(entityId);

            if (kind == null || value == null || display == null) {
                continue;
            }

            readings.add({
                :kind => kind,
                :value => value,
                :unit => getReadingUnit(entityId),
                :display => display
            });
        }

        return readings;
    }

    function getFloorReadings(areaNames as Array<String>) as Array<SensorReading> {
        var readings = [] as Array<SensorReading>;

        for (var areaIndex = 0; areaIndex < areaNames.size(); areaIndex++) {
            readings.addAll(getAreaReadings(areaNames[areaIndex]));
        }

        return readings;
    }

    function getFloorLightStates(areaNames as Array<String>) as LightStates {
        var onCount = 0;
        var availableCount = 0;
        var unavailableCount = 0;

        for (var areaIndex = 0; areaIndex < areaNames.size(); areaIndex++) {
            var states = getLightStates(listLightsInArea(areaNames[areaIndex]));
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
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            if (state.states.hasKey(entityId)) {
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
