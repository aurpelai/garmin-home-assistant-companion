import Toybox.Lang;

// Shared UI-side state passed between the area and light menus: the HA client,
// the immutable server-truth LightState (areas + loaded states), and a mutable
// copy of the states map. Toggles update the mutable copy optimistically so the
// switch flips immediately, leaving the LightState as the untouched server truth.
class LightSession {
    public var client as HaClient;
    private var _state as LightState;
    private var _states as Dictionary<String, Boolean>;   // entity_id -> isOn, mutable

    function initialize(client as HaClient, state as LightState) {
        self.client = client;
        _state = state;
        // Copy the loaded states so optimistic toggles never mutate the
        // LightState (which stays immutable server-truth).
        var copy = {} as Dictionary<String, Boolean>;
        var entityIds = state.states.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            copy.put(entityIds[index], state.isOn(entityIds[index]));
        }
        self._states = copy;
    }

    // Area-structure reads delegate to the LightState so menus don't reach into it.
    function areas() as Array<Dictionary> {
        return _state.areas;
    }

    function listAllLights() as Array<String> {
        return _state.listAllLights();
    }

    function listLightsInArea(name as String) as Array<String> {
        return _state.listLightsInArea(name);
    }

    // HA's display name for a light (bare id as last-resort fallback).
    function getName(entityId as String) as String {
        return _state.getName(entityId);
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
        return (state == null) ? false : (state as Boolean);
    }

    // Availability is server truth only, never optimistically mutated, so it
    // reads straight from the LightState rather than the mutable copy.
    function isAvailable(entityId as String) as Boolean {
        return _state.isAvailable(entityId);
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

    // Re-sync from a freshly fetched LightState (most-recent-fetch wins). The
    // new state becomes the server truth backing structural reads on the next
    // menu construction; the live on/off map converges to it now.
    //
    // Only entities already present in the live map are updated, and only when
    // the fresh state actually knows them — a state that omits an entity leaves
    // its value alone rather than reading the isOn default and flipping it off.
    // Keys are never added or dropped here: structural drift (entities or group
    // membership appearing/disappearing) is deferred to the next navigation.
    function applyState(state as LightState) as Void {
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
        client.fetchLightState(new RefreshHandler(self, onDone).method(:onFetched));
    }
}

class RefreshHandler {
    private var _session as LightSession;
    private var _onDone as Method;

    function initialize(session as LightSession, onDone as Method) {
        _session = session;
        _onDone = onDone;
    }

    function onFetched(state as LightState or Null, error as Number or Null) as Void {
        if (error == null) {
            _session.applyState(state as LightState);
        }
        _onDone.invoke();
    }
}

// Handles a light-toggle result: reverts the optimistic state flip if the
// call failed, then hands off to the UI-side completion callback either way.
class ToggleResultHandler {
    private var _session as LightSession;
    private var _entityId as String;
    private var _attemptedOn as Boolean;
    private var _onComplete as Method;

    function initialize(session as LightSession, entityId as String, attemptedOn as Boolean, onComplete as Method) {
        _session = session;
        _entityId = entityId;
        _attemptedOn = attemptedOn;
        _onComplete = onComplete;
    }

    function onResult(ok as Boolean or Null, error as Number or Null) as Void {
        if (error != null) {
            _session.revertState(_entityId, _attemptedOn);
        }
        _onComplete.invoke();
    }
}
