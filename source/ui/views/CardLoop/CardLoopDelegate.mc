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

    // Which card is focused is the view's presentation state and reaches the
    // coordinator no other way, so the delegate reads it and forwards an intent.
    function onSelect() as Boolean {
        var card = _loop.currentCard();
        if (card != null) {
            (card as Card).open(_coordinator);
        }

        return true;
    }

    // Root of the navigation stack: back has nowhere to return to, so it exits,
    // matching the other root-view delegates.
    function onBack() as Boolean {
        System.exit();
    }
}
