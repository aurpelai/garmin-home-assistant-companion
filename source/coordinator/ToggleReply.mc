import Toybox.Lang;

// Monkey C has no closures, so the coordinator needs an object to receive the
// client's two-argument reply and drop the result it has no use for.
class ToggleReply {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        _coordinator = coordinator;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _coordinator.onToggleSettled(error);
    }
}
