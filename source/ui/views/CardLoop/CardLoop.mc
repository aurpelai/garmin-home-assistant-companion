import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Holds the focused card's id and its floor id, both captured before a push
// replaces the model: a vanished area cannot be looked up afterwards to find
// which floor it sat under, that reference being what disappeared.
class CardLoop extends WatchUi.View {
    private var _coordinator as Coordinator;
    private var _model as CardLoopModel;
    private var _index as Number;
    private var _pageIndicator as PageIndicator;

    function initialize(coordinator as Coordinator, model as CardLoopModel) {
        View.initialize();
        _coordinator = coordinator;
        _model = model;
        _index = 0;
        _pageIndicator = new PageIndicator(model.cards.size());
        setModel(model);
    }

    function rebuild(haState as HaState) as Boolean {
        setModel(CardLoopBuilder.build(haState));
        return true;
    }

    function setModel(model as CardLoopModel) as Void {
        var focused = currentCard();
        var cardId = focused == null ? null : focused.id;
        var floorId = focused == null ? null : focused.floorId;

        _model = model;
        _index = indexOf(cardId, floorId);
        _pageIndicator.setPageCount(model.cards.size(), _index);
    }

    function onShow() as Void {
        _coordinator.onViewShown(self);
        addLayer(_pageIndicator.getLayer());
        _pageIndicator.showIndicator();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
        dc.clear();

        var card = currentCard();
        if (card != null) {
            card.draw(dc);
        }

        if (_pageIndicator.isVisible()) {
            _pageIndicator.draw();
        }
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
        _pageIndicator.onParentViewHide();
        removeLayer(_pageIndicator.getLayer());
        View.onHide();
    }

    function currentCard() as Card or Null {
        return _index < 0 || _index >= _model.cards.size() ? null : _model.cards[_index];
    }

    function showNext() as Void {
        _index = _index < _model.cards.size() - 1 ? _index + 1 : 0;
        _pageIndicator.updateIndex(_index);
    }

    function showPrevious() as Void {
        _index = _index > 0 ? _index - 1 : _model.cards.size() - 1;
        _pageIndicator.updateIndex(_index);
    }

    private function indexOf(cardId as String or Null, floorId as String or Null) as Number {
        var found = cardIndexOf(cardId);

        if (found < 0) {
            found = cardIndexOf(floorId);
        }

        return found < 0 ? 0 : found;
    }

    private function cardIndexOf(cardId as String or Null) as Number {
        if (cardId == null) {
            return -1;
        }

        for (var index = 0; index < _model.cards.size(); index++) {
            if (_model.cards[index].id.equals(cardId)) {
                return index;
            }
        }

        return -1;
    }
}
