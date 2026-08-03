import Toybox.Lang;

// One in-flight whole-floor toggle: a single service call that drives every
// light on the floor to one direction. The optimistic flip overwrites each
// light's own value, so the pre-flip states are carried here to restore exactly
// on failure.
class PendingWholeFloorToggle {
    private var _session as HomeSession;
    private var _savedStates as Dictionary<String, Boolean>;
    private var _onComplete as Method;

    function initialize(session as HomeSession, savedStates as Dictionary<String, Boolean>,
                        onComplete as Method) {
        _session = session;
        _savedStates = savedStates;
        _onComplete = onComplete;
    }

    function onResult(ok as Boolean or Null, error as Number or Null) as Void {
        if (error != null) {
            _session.revertStates(_savedStates);
        }

        _onComplete.invoke();
    }
}
