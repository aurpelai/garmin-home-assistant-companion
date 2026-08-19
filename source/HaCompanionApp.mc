import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// getInitialView returns a plain loading view rather than a Menu2: returning a
// Menu2 here crashes on some devices.
class HaCompanionApp extends Application.AppBase {
    private var _coordinator as Coordinator;

    function initialize() {
        AppBase.initialize();
        _coordinator = new Coordinator(new HaClient());
    }

    function onStart(state as Dictionary or Null) as Void {
        if (!Settings.isConfigured()) {
            return;
        }

        _coordinator.onActivate();
    }

    function onActive(state as Dictionary or Null) as Void {
        if (!Settings.isConfigured()) {
            return;
        }

        _coordinator.onActivate();
    }

    function onSettingsChanged() as Void {
        _coordinator.discardRegistration();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        if (!Settings.isConfigured()) {
            return [new InfoView(WatchUi.loadResource(Rez.Strings.ErrNoConfig) as String, true, null),
                    new InfoDelegate(_coordinator)];
        }

        return [new LoadingView(_coordinator), new LoadingDelegate()];
    }
}
