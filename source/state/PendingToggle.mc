import Toybox.Lang;

// One in-flight single-light toggle. Carries the light's pre-flip state so a
// failed call restores exactly that — not whatever the map holds at reply time,
// which a refresh landing mid-flight could have overwritten with server truth.
class PendingToggle {
    private var _session as HomeSession;
    private var _entityId as String;
    private var _savedState as Boolean;
    private var _onComplete as Method;

    function initialize(session as HomeSession, entityId as String, savedState as Boolean,
                        onComplete as Method) {
        _session = session;
        _entityId = entityId;
        _savedState = savedState;
        _onComplete = onComplete;
    }

    function onResult(ok as Boolean or Null, error as Number or Null) as Void {
        if (error != null) {
            _session.revertToggle(_entityId, _savedState);
        }

        _onComplete.invoke();
    }
}
