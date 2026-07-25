import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// App entry point. getInitialView() must return a View + InputDelegate pair —
// returning a Menu2 directly here crashes on some devices, so the first screen
// is a plain loading view that kicks off the initial HA fetch in onShow().
//
// Resume/foreground handling lives in the views, not here: the top menu's
// onShow fires on return to the foreground and reconciles there, so no
// AppBase-level resume hook is wired.
class HaControllerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LoadingView(), new LoadingDelegate()];
    }
}
