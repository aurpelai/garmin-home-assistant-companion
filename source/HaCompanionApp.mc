import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// getInitialView returns a plain loading view rather than a Menu2: returning a
// Menu2 here crashes on some devices.
class HaCompanionApp extends Application.AppBase {
    private var _client as HaClient;
    private var _session as HomeSession or Null;
    private var _currentView as WatchUi.Views or Null;

    function initialize() {
        AppBase.initialize();
        _client = new HaClient();
        _session = null;
        _currentView = null;
    }

    function onStart(state as Dictionary or Null) as Void {
        if (_session == null) {
            return;
        }
        _session.refreshState(method(:onRefreshed));
    }

    function onActive(state as Dictionary or Null) as Void {
        if (_session == null) {
            return;
        }
        _session.refreshState(method(:onRefreshed));
    }

    // A fresh HaClient, not _session's: settings can change before the first
    // load, when there is no session yet. onSettingsChanged only fires when
    // the URL or token actually changed, so registering here needs no
    // comparison against a remembered prior value.
    function onSettingsChanged() as Void {
        _client.register(method(:noOpRegister));
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

    function fetchHomeState() as Void {
        _client.fetchHomeState(method(:onLoaded));
    }

    function noOpRegister(state as Dictionary or Null, error as String or Null) as Void {}

    function showRetryScreen(id as ResourceId, code as Number or Null) as Void {
        var message = WatchUi.loadResource(id) as String;

        if (code != null) {
            message = Lang.format(WatchUi.loadResource(Rez.Strings.ErrCode) as String, [code]) + ":\n" + message;
        }

        WatchUi.switchToView(
            new ErrorView(message),
            new ErrorDelegate(),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function onLoaded(state as HomeState or Null, error as Number or Null) as Void {
        if (error != null) {
            showRetryScreen(resolveErrorMessage(error), error);
            return;
        }

        if (state == null) {
            showRetryScreen(Rez.Strings.ErrNullHaState, null);
            return;
        }

        if (state.isUnparsed()) {
            showRetryScreen(Rez.Strings.ErrUnparsedHaState, null);
            return;
        }

        if (state.isEmpty()) {
            showRetryScreen(Rez.Strings.ErrEmptyHaState, null);
            return;
        }

        // Safe to swap the session wholesale only because this runs at
        // startup/retry, before any view holds it. Mid-session refresh must go
        // through applyState instead, or injected references would diverge.
        var session = setSession(state);
        var cardLoopView = new CardLoopView(session);

        WatchUi.switchToView(
            cardLoopView,
            new CardLoopDelegate(cardLoopView, session),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function resolveErrorMessage(code as Number) as ResourceId {
        if (code == 401 || code == 403) {
            return Rez.Strings.ErrAuth;
        }

        if (code == 404) {
            return Rez.Strings.ErrNotFound;
        }

        if (code < 0) {
            return Rez.Strings.ErrNetwork;
        }

        return Rez.Strings.ErrUnknown;
    }
}
