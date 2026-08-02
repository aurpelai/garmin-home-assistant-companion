import Toybox.Lang;

// Handles a light-toggle result: reverts the optimistic state flip if the
// call failed, then hands off to the UI-side completion callback either way.
class ToggleResultHandler {
    private var _session as HomeSession;
    private var _entityId as String;
    private var _attemptedOn as Boolean;
    private var _onComplete as Method;

    function initialize(session as HomeSession, entityId as String, attemptedOn as Boolean, onComplete as Method) {
        _session = session;
        _entityId = entityId;
        _attemptedOn = attemptedOn;
        _onComplete = onComplete;
    }

    function onResult(ok as Boolean or Null, error as Number or Null) as Void {
        if (error != null) {
            _session.revertState(_entityId, _attemptedOn);
        }
        _onComplete.invoke();
    }
}
