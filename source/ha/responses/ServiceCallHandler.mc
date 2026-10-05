import Toybox.Lang;

class ServiceCallHandler {
    private var _callback as Method;
    private var _refreshManager as RefreshManager;
    private var _target as Symbol;

    function initialize(callback as Method, refreshManager as RefreshManager, domain as String) {
        _callback = callback;
        _refreshManager = refreshManager;
        _target = domain.equals(Domain.FAN) ? FetchTarget.FANS : FetchTarget.LIGHTS;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _callback.invoke(result, error);
        _refreshManager.fetch(_target);
    }

    function invalidateTarget() as Void {
        _refreshManager.invalidate(_target);
    }
}
