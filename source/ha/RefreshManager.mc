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
    private var _latestEpochs as Dictionary<Symbol, Number>;
    private var _outstanding as Dictionary<Symbol, Boolean>;
    private var _errors as Dictionary<Symbol, RequestError>;

    function initialize(buildRequest as Method, onTarget as Method, scheduler as Scheduler) {
        _buildRequest = buildRequest;
        _onTarget = onTarget;
        _scheduler = scheduler;
        _epoch = 0;
        _latestEpochs = {};
        _outstanding = {};
        _errors = {};
    }

    function onSettled(epoch as Number, result as Object or Null, error as RequestError or Null) as Void {
        var target = findTarget(epoch);

        if (target == null) {
            return;
        }

        _outstanding.remove(target);

        if (error != null) {
            if (error.request == null) {
                error.request = target;
            }

            _errors.put(target, error);
        }

        _onTarget.invoke(target, result, !isFetching());
    }

    function isFetching() as Boolean {
        return _outstanding.size() > 0;
    }

    function getErrors() as Array<RequestError> {
        var errors = [] as Array<RequestError>;

        for (var i = 0; i < TARGETS.size(); i++) {
            var error = _errors.get(TARGETS[i]);

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
        var epoch = invalidate(target);
        new RetryManager(_buildRequest.invoke(target) as Method,
            new EpochHandler(method(:onSettled), epoch).method(:onSettled), _scheduler, RequestType.REQUEST).attempt();
    }

    function invalidate(target as Symbol) as Number {
        if (!isFetching()) {
            _errors = {};
        }

        _epoch++;
        _latestEpochs.put(target, _epoch);
        _outstanding.put(target, true);
        _errors.remove(target);

        return _epoch;
    }

    function reset() as Void {
        _latestEpochs = {};
        _outstanding = {};
        _errors = {};
    }

    private function findTarget(epoch as Number) as Symbol or Null {
        var targets = _latestEpochs.keys();

        for (var i = 0; i < targets.size(); i++) {
            if (_latestEpochs.get(targets[i]) == epoch) {
                return targets[i] as Symbol;
            }
        }

        return null;
    }
}
