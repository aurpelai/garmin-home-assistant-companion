import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// getInitialView returns a plain loading view rather than a Menu2: returning a
// Menu2 here crashes on some devices.
class HaControllerApp extends Application.AppBase {
    private var _session as HomeSession or Null;
    private var _currentView as WatchUi.Views or Null;

    function initialize() {
        AppBase.initialize();
        _session = null;
        _currentView = null;
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LoadingView(), new LoadingDelegate()];
    }

    function setSession(session as HomeSession) as Void {
        _session = session;
    }

    function setCurrentView(view as WatchUi.Views) as Void {
        _currentView = view;
    }

    function onActive(state as Dictionary or Null) as Void {
        if (_session == null) {
            return;
        }
        _session.refreshState(method(:onRefreshed));
    }

    // A fresh HaClient, not _session's: settings can change before the first
    // load, when there is no session yet.
    function onSettingsChanged() as Void {
        Settings.registerIfNeeded(new HaClient(), method(:onSettingsRegistered));
    }

    function onSettingsRegistered(webhookId as String or Null, error as Number or Null) as Void {
    }

    function onRefreshed() as Void {
        // No interface to type this against (Menu2 owns the single base slot),
        // so the draw call is a duck-typed cast union — a new state-showing
        // view must be added to it.
        var view = _currentView;
        if (view != null && view has :draw) {
            (view as AreaEntityMenu or FloorEntityMenu or CardLoopView).draw();
        }
    }
}
