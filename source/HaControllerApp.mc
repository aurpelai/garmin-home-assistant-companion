import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// getInitialView returns a plain loading view rather than a Menu2: returning a
// Menu2 here crashes on some devices.
class HaControllerApp extends Application.AppBase {
    private var _client as HaClient;
    private var _session as HomeSession or Null;
    private var _currentView as WatchUi.Views or Null;

    function initialize() {
        AppBase.initialize();
        _client = new HaClient();
        _session = null;
        _currentView = null;
        registerNativeAppToHomeAssistant();
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
        registerIfNeeded();
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

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LoadingView(), new LoadingDelegate()];
    }

    function setSession(state as HomeState) as HomeSession {
        var session = new HomeSession(_client, state);
        _session = session;
        return session;
    }

    function setCurrentView(view as WatchUi.Views) as Void {
        _currentView = view;
    }

    function fetchHomeState(callback as Method) as Void {
        _client.fetchHomeState(callback);
    }

    function registerNativeAppToHomeAssistant() as Void {
        Settings.clearWebhookId();
        _client.register(method(:noOpRegister));
    }

    function registerIfNeeded() as Void {
        var baseUrl = Settings.getBaseUrl();
        var registeredUrl = Settings.getRegisteredUrl();

        // A URL change clears the stale id and falls through to register; only a
        // still-valid id short-circuits, so a token-only change never re-registers.
        if (registeredUrl != null && !(registeredUrl as String).equals(baseUrl)) {
            Settings.clearWebhookId();
        } else if (Settings.getWebhookId() != null) {
            return;
        }

        _client.register(method(:noOpRegister));
    }

    function noOpRegister(state as Dictionary or Null, error as String or Null) as Void {}
}
