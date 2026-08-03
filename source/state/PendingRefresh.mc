import Toybox.Lang;

// A failed fetch is swallowed (last-known state stays and heals on the next
// trigger), yet the completion still fires so callers need no error branch.
class PendingRefresh {
    private var _session as HomeSession;
    private var _onDone as Method;

    function initialize(session as HomeSession, onDone as Method) {
        _session = session;
        _onDone = onDone;
    }

    function onFetched(state as HomeState or Null, error as Number or Null) as Void {
        if (error == null) {
            _session.applyState(state as HomeState);
        }

        _onDone.invoke();
    }
}
