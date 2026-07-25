import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// App entry point. getInitialView() must return a View + InputDelegate pair —
// returning a Menu2 directly here crashes on some devices, so the first screen
// is a plain loading view that kicks off the initial HA fetch in onShow().
//
// Resume/foreground handling lives in the views, not here: a widget is torn
// down when backgrounded and getInitialView runs afresh on return, so the
// initial LoadingView fetch already reconciles on that path. Where a device
// instead keeps the app alive, the top LightMenu's onShow fires on re-display
// and reconciles there. There is no long-lived session for an AppBase-level
// resume hook to converge, so none is wired.
class HaControllerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LoadingView(), new LoadingDelegate()];
    }
}
