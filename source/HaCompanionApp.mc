import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// UNVERIFIED: getInitialView returns a plain loading view rather than a Menu2
// because returning a Menu2 here crashes on some devices.
//
// The coordinator owns the client and state, neither of which exists in the
// glance or background process. It is built on the first full-app entry
// (getInitialView) and left null elsewhere, where the lifecycle callbacks skip it.
(:glance, :background, :typecheck([disableGlanceCheck, disableBackgroundCheck]))
class HaCompanionApp extends Application.AppBase {
    private const REFRESH_PERIOD_S = 15 * 60;

    private var _coordinator as Coordinator or Null;

    function initialize() {
        AppBase.initialize();
        _coordinator = null;
    }

    function onActive(state as Dictionary or Null) as Void {
        activate();
        scheduleBackgroundRefresh();
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new GlanceService()];
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
        var coordinator = getOrCreateCoordinator();

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

    // Re-registering while an event is pending pushes it further out, so a
    // frequently-activated app would never let the refresh fire.
    private function scheduleBackgroundRefresh() as Void {
        if (!Settings.isConfigured() || Background.getTemporalEventRegisteredTime() != null) {
            return;
        }

        Background.registerForTemporalEvent(new Time.Duration(REFRESH_PERIOD_S));
    }

    private function getOrCreateCoordinator() as Coordinator {
        if (_coordinator == null) {
            _coordinator = new Coordinator(new HaClient());
        }

        return _coordinator;
    }
}
