import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CardLoopDelegate extends WatchUi.BehaviorDelegate {
    private var _loop as CardLoop;
    private var _coordinator as Coordinator;

    function initialize(loop as CardLoop, coordinator as Coordinator) {
        BehaviorDelegate.initialize();
        _loop = loop;
        _coordinator = coordinator;
    }

    function onNextPage() as Boolean {
        _loop.showNext();
        return true;
    }

    function onPreviousPage() as Boolean {
        _loop.showPrevious();
        return true;
    }

    function onSelect() as Boolean {
        var card = _loop.currentCard();
        if (card != null) {
            (card as Card).open(_coordinator);
        }

        return true;
    }

    function onBack() as Boolean {
        System.exit();
    }
}
