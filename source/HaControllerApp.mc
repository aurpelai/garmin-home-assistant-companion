import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// App entry point. getInitialView() must return a View + InputDelegate pair —
// returning a Menu2 directly here crashes on some devices, so the first screen
// is a plain loading view that kicks off the initial HA fetch in onShow().
//
// Resume/foreground handling lives in onActive(): the task-switcher fires it on
// return to the foreground, and it refreshes the app-owned session in place
// then redraws the current state-showing view. The app holds two references
// for this — the live session (written once by LoadingView.onLoaded) and the
// current view (registered by each state-showing view's onShow).
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

    // Replace the live session (LoadingView.onLoaded, at startup/retry).
    function setSession(session as HomeSession) as Void {
        _session = session;
    }

    // Register the view onActive should redraw (a state-showing view's onShow).
    function setCurrentView(view as WatchUi.Views) as Void {
        _currentView = view;
    }

    // Task-switcher foreground hook. With no session yet (mid-load, ErrorView)
    // this is inert — LoadingView owns the fetch there. Otherwise refresh the
    // session in place off a fresh HomeState, then redraw the current view.
    function onActive(state as Dictionary or Null) as Void {
        if (_session == null) {
            return;
        }
        _session.refreshState(method(:onRefreshed));
    }

    function onRefreshed() as Void {
        // Duck-typed redraw: Monkey C has no interfaces and Menu2 owns the
        // single base-class slot, so state-showing views expose a named redraw
        // method instead. Skip when no view is registered (state-apply only). A
        // new state-showing view must join the cast union below.
        var view = _currentView;
        if (view != null && view has :redraw) {
            (view as EntityMenu or AreaMenu).redraw();
        }
    }
}
