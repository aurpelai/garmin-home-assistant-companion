import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CardLoopDelegate extends WatchUi.BehaviorDelegate {
    private var _view as CardLoopView;
    private var _session as HomeSession;

    function initialize(view as CardLoopView, session as HomeSession) {
        BehaviorDelegate.initialize();
        _view = view;
        _session = session;
    }

    function onNextPage() as Boolean {
        _view.showNext();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.showPrevious();
        return true;
    }

    function onSelect() as Boolean {
        var card = _view.getCurrentCard();
        if (card == null || !(card.get(:selectable) as Boolean)) {
            return true;
        }

        var name = card.get(:name) as String;
        var menu = new EntityMenu(_session, name, _session.listLightsInArea(name),
                                  _session.listSensorsInArea(name));
        WatchUi.pushView(menu, new EntityMenuDelegate(menu, _session), WatchUi.SLIDE_LEFT);
        return true;
    }

    // Root of the navigation stack (reached via switchToView): back has nowhere
    // to return to, so it exits the app — matching ErrorDelegate/LoadingDelegate,
    // the other two root-view delegates.
    function onBack() as Boolean {
        System.exit();
    }
}
