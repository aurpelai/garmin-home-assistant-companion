import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Top-level navigation: a single-focus, paged card loop replacing the old flat
// area list. The sequence is built by walking the session's grouped floor
// structure into a flat list of cards: a floor's (non-selectable) collection
// card, then that floor's area cards, floor by floor; then any unfloored areas
// as plain area cards with no floor header.
//
// UP/DOWN page one card at a time (SWIPE_UP/SWIPE_DOWN do the same, for free,
// via BehaviorDelegate's onNextPage/onPreviousPage); the loop does not wrap.
// START drills an area card into the existing EntityMenu; it is a no-op on a
// floor card. BACK exits the loop.
//
// Card content is recomputed from the session on every show/redraw rather than
// snapshotted at construction, so the loop always reflects live state.
class CardLoopView extends WatchUi.View {
    private var _session as HomeSession;
    private var _cards as Array<Dictionary>;
    private var _index as Number;

    function initialize(session as HomeSession) {
        View.initialize();
        _session = session;
        _cards = [] as Array<Dictionary>;
        _index = 0;
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        redraw();
    }

    // The named redraw seam onActive dispatches to (see EntityMenu.redraw).
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
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var card = getCurrentCard();
        if (card == null) {
            CenteredMessage.draw(dc, WatchUi.loadResource(Rez.Strings.NoEntitiesInAnyArea) as String);
            return;
        }

        drawCard(dc, card as Dictionary);
    }

    private function drawCard(dc as Graphics.Dc, card as Dictionary) as Void {
        var width = dc.getWidth();
        var centerX = width / 2;
        var titleFont = Graphics.FONT_MEDIUM;
        var subFont = Graphics.FONT_TINY;
        var floorFont = Graphics.FONT_XTINY;
        var y = dc.getHeight() / 4;

        var floor = card.get(:floor);
        if (floor != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(centerX, y, floorFont, floor as String, Graphics.TEXT_JUSTIFY_CENTER);
            y += dc.getFontHeight(floorFont);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(centerX, y, titleFont, card.get(:name) as String, Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(titleFont) + 8;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        var lightSummary = card.get(:lightSummary);
        if (lightSummary != null) {
            dc.drawText(centerX, y, subFont, lightSummary as String, Graphics.TEXT_JUSTIFY_CENTER);
            y += dc.getFontHeight(subFont);
        }

        var sensorSummary = card.get(:sensorSummary) as Array<Dictionary>;
        for (var index = 0; index < sensorSummary.size(); index++) {
            var entry = sensorSummary[index];
            var value = entry.hasKey(:range) ? entry.get(:range) : entry.get(:reading);
            dc.drawText(centerX, y, subFont, value as String, Graphics.TEXT_JUSTIFY_CENTER);
            y += dc.getFontHeight(subFont);
        }

        drawPageDots(dc);
    }

    private function drawPageDots(dc as Graphics.Dc) as Void {
        var count = _cards.size();
        if (count <= 1) {
            return;
        }

        var radius = 3;
        var spacing = radius * 3;
        var x = radius * 2;
        var top = (dc.getHeight() - (count - 1) * spacing) / 2;

        for (var index = 0; index < count; index++) {
            dc.setColor(index == _index ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, top + index * spacing, radius);
        }
    }
}

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
