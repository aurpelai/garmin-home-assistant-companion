import Toybox.Lang;

// Binds the override ids a toggle created to the client's single-callback-
// argument shape, so the reply clears exactly those ids rather than
// recomputing a scope that may have changed since the request went out.
class ToggleReply {
    private var _coordinator as Coordinator;
    private var _overriddenIds as Array<String>;

    function initialize(coordinator as Coordinator, overriddenIds as Array<String>) {
        _coordinator = coordinator;
        _overriddenIds = overriddenIds;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _coordinator.onToggleSettled(_overriddenIds, error);
    }
}
