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

        if (card.get(:type) == :floor) {
            openFloorMenu(card);
        } else {
            openAreaMenu(card);
        }

        return true;
    }

    private function openFloorMenu(card as Dictionary) as Void {
        var menu = new AllLightsMenu(_session, card.get(:id) as String, card.get(:name) as String);
        WatchUi.pushView(menu, new AllLightsMenuDelegate(menu, _session), WatchUi.SLIDE_LEFT);
    }

    private function openAreaMenu(card as Dictionary) as Void {
        var name = card.get(:name) as String;
        var menu = new EntityMenu(_session, name, _session.listLightsInArea(name),
                                  _session.listSensorsInArea(name));
        WatchUi.pushView(menu, new EntityMenuDelegate(menu, _session), WatchUi.SLIDE_LEFT);
    }

    // Root of the navigation stack (reached via switchToView): back has nowhere
    // to return to, so it exits the app — matching ErrorDelegate/LoadingDelegate,
    // the other two root-view delegates.
    function onBack() as Boolean {
        System.exit();
    }
}
