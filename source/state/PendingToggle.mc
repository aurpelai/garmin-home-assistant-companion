import Toybox.Lang;

// Carries the pre-flip state rather than recovering it from the map on failure:
// a refresh landing mid-flight could have overwritten the map with server truth.
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
