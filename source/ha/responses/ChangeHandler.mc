import Toybox.Lang;

class ChangeHandler {
    private var _callback as Method;
    private var _refreshManager as RefreshManager;
    private var _target as Symbol;

    function initialize(callback as Method, refreshManager as RefreshManager, target as Symbol) {
        _callback = callback;
        _refreshManager = refreshManager;
        _target = target;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _callback.invoke(result, error);
        _refreshManager.fetch(_target);
    }
}
