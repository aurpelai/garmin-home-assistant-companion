import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// UNVERIFIED: getInitialView returns a plain loading view rather than a Menu2
// because returning a Menu2 here crashes on some devices.
//
// The coordinator owns the client and state, neither of which exists in the
// glance process. It is built on the first full-app entry (getInitialView) and
// left null in glance mode, where the lifecycle callbacks below skip it.
(:glance, :typecheck(disableGlanceCheck))
class HaCompanionApp extends Application.AppBase {
    private var _coordinator as Coordinator or Null;

    function initialize() {
        AppBase.initialize();
        _coordinator = null;
    }

    function onStart(state as Dictionary or Null) as Void {
        activate();
    }

    function onActive(state as Dictionary or Null) as Void {
        activate();
    }

    function onSettingsChanged() as Void {
        if (_coordinator != null) {
            _coordinator.discardRegistration();
        }
    }

    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new GlanceView()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var coordinator = coordinator();

        if (!Settings.isConfigured()) {
            return [new InfoView(WatchUi.loadResource(Rez.Strings.ErrNoConfig) as String, true, null),
                    new InfoDelegate(coordinator)];
        }

        return [new LoadingView(coordinator), new LoadingDelegate()];
    }

    private function activate() as Void {
        var coordinator = _coordinator;

        if (coordinator != null && Settings.isConfigured()) {
            coordinator.onActivate();
        }
    }

    private function coordinator() as Coordinator {
        if (_coordinator == null) {
            _coordinator = new Coordinator(new HaClient());
        }

        return _coordinator;
    }
}
