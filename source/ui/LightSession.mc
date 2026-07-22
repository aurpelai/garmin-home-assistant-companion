import Toybox.Lang;

// Shared UI-side state passed between the area and light menus: the HA client,
// the immutable server-truth LightState (areas + loaded states), and a mutable
// copy of the states map. Toggles update the mutable copy optimistically so the
// switch flips immediately, leaving the LightState as the untouched server truth.
class LightSession {
    public var client as HaClient;
    private var _state as LightState;
    public var states as Dictionary<String, Boolean>;   // entity_id -> isOn, mutable

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
        self.states = copy;
    }

    // Area-structure reads delegate to the LightState so menus don't reach into it.
    function areas() as Array<Dictionary> {
        return _state.areas;
    }

    function allLights() as Array<String> {
        return _state.allLights();
    }

    function lightsForArea(name as String) as Array<String> {
        return _state.lightsForArea(name);
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

    function isOn(entityId as String) as Boolean {
        var state = states.get(entityId);
        return (state == null) ? false : (state as Boolean);
    }

    // Flip local state and fire the toggle. The result callback reconciles on
    // failure (reverts the optimistic flip).
    function toggle(entityId as String, onComplete as Method) as Void {
        var newOn = !isOn(entityId);
        states.put(entityId, newOn);
        client.callLightService(ServiceCall.SERVICE_TOGGLE, entityId,
            new ToggleResultHandler(self, entityId, newOn, onComplete).method(:onResult));
    }

    function revert(entityId as String, attemptedOn as Boolean) as Void {
        states.put(entityId, !attemptedOn);
    }
}

// Handles a light service-call result: reverts the optimistic state flip if the
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
            _session.revert(_entityId, _attemptedOn);
        }
        _onComplete.invoke();
    }
}
