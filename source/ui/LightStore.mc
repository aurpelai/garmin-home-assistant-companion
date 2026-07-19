import Toybox.Lang;

// Shared UI-side state passed between the area and light menus: the HA client,
// the parsed area→lights map, and the current on/off map (entity_id -> Boolean).
// Toggles update the local state optimistically so the icon flips immediately.
class LightStore {
    public var client as HaClient;
    public var map as AreaLightMap;
    public var states as Dictionary;   // entity_id -> Boolean (isOn)

    function initialize(client as HaClient, map as AreaLightMap, states as Dictionary) {
        self.client = client;
        self.map = map;
        self.states = states;
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
