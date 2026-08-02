import Toybox.Lang;

// Handles a floor-toggle result: on failure restores every affected light to
// the on/off value captured before the optimistic flip, then hands off to the
// UI-side completion callback either way.
class FloorToggleResultHandler {
    private var _session as HomeSession;
    private var _priorOn as Dictionary<String, Boolean>;
    private var _onComplete as Method;

    function initialize(session as HomeSession, priorOn as Dictionary<String, Boolean>,
                        onComplete as Method) {
        _session = session;
        _priorOn = priorOn;
        _onComplete = onComplete;
    }

    function onResult(ok as Boolean or Null, error as Number or Null) as Void {
        if (error != null) {
            _session.revertStates(_priorOn);
        }

        _onComplete.invoke();
    }
}
