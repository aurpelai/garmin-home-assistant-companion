import Toybox.Lang;

class ToggleReply {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        _coordinator = coordinator;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _coordinator.onToggleSettled(error);
    }
}
