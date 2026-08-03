import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Top-level navigation: a single-focus, paged card loop replacing the old flat
// area list. The sequence is built by walking the session's grouped floor
// structure into a flat list of cards: a floor's (non-selectable) collection
// card, then that floor's area cards, floor by floor; then any unfloored areas
// as plain area cards with no floor header.
//
// UP/DOWN page one card at a time (SWIPE_UP/SWIPE_DOWN do the same, for free,
// via BehaviorDelegate's onNextPage/onPreviousPage); the loop wraps at both ends.
// START drills an area card into the existing AreaEntityMenu; it is a no-op on a
// floor card. BACK exits the loop.
//
// Card content is recomputed from the session on every show/redraw rather than
// snapshotted at construction, so the loop always reflects live state.
class CardLoopView extends WatchUi.View {
    private var _session as HomeSession;
    private var _cards as Array<Dictionary>;
    private var _index as Number;
    private var _renderer as CardRenderer;

    function initialize(session as HomeSession) {
        View.initialize();
        _session = session;
        _cards = [] as Array<Dictionary>;
        _index = 0;
        _renderer = new CardRenderer();
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        redraw();
    }

    // The named redraw seam onActive dispatches to (see AreaEntityMenu.redraw).
    // Rebuilds the card sequence from the session's live state and clamps the
    // current index onto it, preserving position when the sequence shrinks.
    function redraw() as Void {
        _cards = CardModel.buildCards(_session);
        if (_index >= _cards.size()) {
            _index = _cards.size() == 0 ? 0 : _cards.size() - 1;
        }
        WatchUi.requestUpdate();
    }

    function getCurrentCard() as Dictionary or Null {
        if (_index < 0 || _index >= _cards.size()) {
            return null;
        }
        return _cards[_index];
    }

    function showNext() as Void {
        if (_index < _cards.size() - 1) {
            _index++;
            WatchUi.requestUpdate();
        } else {
            _index = 0;
            WatchUi.requestUpdate();
        }
    }

    function showPrevious() as Void {
        if (_index > 0) {
            _index--;
            WatchUi.requestUpdate();
        } else {
            _index = _cards.size() - 1;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.clear();

        var card = getCurrentCard();

        if (card == null) {
            CenteredMessage.draw(dc, WatchUi.loadResource(Rez.Strings.NoEntitiesInAnyArea) as String);
            return;
        }

        _renderer.drawCard(dc, card as Dictionary, _cards.size(), _index);
    }
}
