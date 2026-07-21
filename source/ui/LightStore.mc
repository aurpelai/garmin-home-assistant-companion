import Toybox.Lang;

// Shared UI-side state passed between the area and light menus: the HA client,
// the immutable server-truth snapshot (areas + loaded states), and a mutable
// copy of the states map. Toggles update the mutable copy optimistically so the
// icon flips immediately, leaving the snapshot as the untouched server truth.
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
        var keys = snapshot.states.keys();
        for (var i = 0; i < keys.size(); i++) {
            copy.put(keys[i], snapshot.isOn(keys[i]));
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
    function toggle(entityId as String, onDone as Method) as Void {
        var newOn = !isOn(entityId);
        states.put(entityId, newOn);
        client.callLightService(ServiceCall.SERVICE_TOGGLE, entityId,
            new ToggleReconciler(self, entityId, newOn, onDone).method(:onResult));
    }

    function revert(entityId as String, attemptedOn as Boolean) as Void {
        states.put(entityId, !attemptedOn);
    }
}

// Reverts the optimistic state flip if the service call failed.
class ToggleReconciler {
    private var _store as LightStore;
    private var _entityId as String;
    private var _attemptedOn as Boolean;
    private var _onDone as Method;

    function initialize(store as LightStore, entityId as String, attemptedOn as Boolean, onDone as Method) {
        _store = store;
        _entityId = entityId;
        _attemptedOn = attemptedOn;
        _onDone = onDone;
    }

    function onResult(ok as Boolean or Null, err as Number or Null) as Void {
        if (err != null) {
            _store.revert(_entityId, _attemptedOn);
        }
        _onDone.invoke();
    }
}
