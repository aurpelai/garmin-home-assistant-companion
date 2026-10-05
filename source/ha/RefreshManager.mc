import Toybox.Lang;

// Only the newest request for a target counts: every request takes the next
// epoch and a reply carrying any other epoch is dropped, so a superseded fetch
// can never overwrite fresher state.
class RefreshManager {
    private const TARGETS = [FetchTarget.STRUCTURE, FetchTarget.LIGHTS, FetchTarget.FANS, FetchTarget.SENSORS];

    private var _buildRequest as Method;
    private var _onTarget as Method;
    private var _scheduler as Scheduler;
    private var _epoch as Number;
    private var _latestEpochByTarget as Dictionary<Symbol, Number>;
    private var _unsettledTargets as Dictionary<Symbol, Boolean>;
    private var _errorByTarget as Dictionary<Symbol, RequestError>;

    function initialize(buildRequest as Method, onTarget as Method, scheduler as Scheduler) {
        _buildRequest = buildRequest;
        _onTarget = onTarget;
        _scheduler = scheduler;
        _epoch = 0;
        _latestEpochByTarget = {};
        _unsettledTargets = {};
        _errorByTarget = {};
    }

    function onSettled(epoch as Number, result as Object or Null, error as RequestError or Null) as Void {
        var target = findTarget(epoch);

        if (target == null) {
            return;
        }

        _unsettledTargets.remove(target);

        if (error != null) {
            if (error.request == null) {
                error.request = target;
            }

            _errorByTarget.put(target, error);
        }

        _onTarget.invoke(target, result, !isFetching());
    }

    function isFetching() as Boolean {
        return _unsettledTargets.size() > 0;
    }

    function getErrors() as Array<RequestError> {
        var errors = [] as Array<RequestError>;

        for (var i = 0; i < TARGETS.size(); i++) {
            var error = _errorByTarget.get(TARGETS[i]);

            if (error != null) {
                errors.add(error);
            }
        }

        return errors;
    }

    function fetchAll() as Void {
        for (var i = 0; i < TARGETS.size(); i++) {
            fetch(TARGETS[i]);
        }
    }

    function fetch(target as Symbol) as Void {
        invalidate(target);

        var epoch = _latestEpochByTarget.get(target) as Number;
        new RetryManager(_buildRequest.invoke(target) as Method,
            new EpochHandler(method(:onSettled), epoch).method(:onSettled), _scheduler, RequestType.REQUEST).attempt();
    }

    function invalidate(target as Symbol) as Void {
        if (!isFetching()) {
            _errorByTarget = {};
        }

        _epoch++;
        _latestEpochByTarget.put(target, _epoch);
        _unsettledTargets.put(target, true);
        _errorByTarget.remove(target);
    }

    function reset() as Void {
        _latestEpochByTarget = {};
        _unsettledTargets = {};
        _errorByTarget = {};
    }

    private function findTarget(epoch as Number) as Symbol or Null {
        var targets = _latestEpochByTarget.keys();

        for (var i = 0; i < targets.size(); i++) {
            if (_latestEpochByTarget.get(targets[i]) == epoch) {
                return targets[i] as Symbol;
            }
        }

        return null;
    }
}
