import Toybox.Lang;

// Shared UI-side state passed between the area and light menus: the HA client,
// the immutable server-truth snapshot (areas + loaded states), and a mutable
// copy of the states map. Toggles update the mutable copy optimistically so the
// switch flips immediately, leaving the snapshot as the untouched server truth.
class LightStore {
    public var client as HaClient;
    private var _snapshot as LightSnapshot;
    public var states as Dictionary<String, Boolean>;   // entity_id -> isOn, mutable

    function initialize(client as HaClient, snapshot as LightSnapshot) {
        self.client = client;
        _snapshot = snapshot;
        // Copy the snapshot's states so optimistic toggles never mutate the
        // snapshot (which stays immutable server-truth).
        var copy = {} as Dictionary<String, Boolean>;
        var entityIds = snapshot.states.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            copy.put(entityIds[index], snapshot.isOn(entityIds[index]));
        }
        self.states = copy;
    }

    // Area-structure reads delegate to the snapshot so menus don't reach into it.
    function areas() as Array<Dictionary> {
        return _snapshot.areas;
    }

    function allLights() as Array<String> {
        return _snapshot.allLights();
    }

    function lightsForArea(name as String) as Array<String> {
        return _snapshot.lightsForArea(name);
    }

    function isOn(entityId as String) as Boolean {
        var v = states.get(entityId);
        return (v == null) ? false : (v as Boolean);
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
    private var _store as LightStore;
    private var _entityId as String;
    private var _attemptedOn as Boolean;
    private var _onComplete as Method;

    function initialize(store as LightStore, entityId as String, attemptedOn as Boolean, onComplete as Method) {
        _store = store;
        _entityId = entityId;
        _attemptedOn = attemptedOn;
        _onComplete = onComplete;
    }

    function onResult(ok as Boolean or Null, err as Number or Null) as Void {
        if (err != null) {
            _store.revert(_entityId, _attemptedOn);
        }
        _onComplete.invoke();
    }
}
