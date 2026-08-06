import Rez.Styles;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class CardLoopView extends WatchUi.View {
    private var _session as HomeSession;
    private var _cards as Array<Dictionary>;
    private var _index as Number;
    private var _renderer as CardRenderer;

    private var _pageIndicator as PageIndicator;

    function initialize(session as HomeSession) {
        View.initialize();
        _session = session;
        _cards = CardModel.buildCards(_session);
        _index = 0;
        _renderer = new CardRenderer();
        _pageIndicator = new PageIndicator(_cards.size());
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        addLayer(_pageIndicator.getLayer());
        _pageIndicator.showIndicator();
        draw();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(system_color_dark__text.color, system_color_dark__background.background);
        dc.clear();

        var card = getCurrentCard();

        if (card == null) {
            WatchUi.switchToView(
                new ErrorView(WatchUi.loadResource(Rez.Strings.NoEntitiesInAnyArea) as String),
                new ErrorDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
            return;
        }

        _renderer.drawCard(dc, card as Dictionary);

        if (_pageIndicator.isVisible()) {
            _pageIndicator.draw();
        }
    }

    function onHide() as Void {
        _pageIndicator.onParentViewHide();
        removeLayer(_pageIndicator.getLayer());
        View.onHide();
    }

    function draw() as Void {
        _cards = CardModel.buildCards(_session);
        if (_index >= _cards.size()) {
            _index = _cards.size() == 0
                ? 0
                : _cards.size() - 1;
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
        _index = _index < _cards.size() - 1
            ? _index + 1
            : 0;
        _pageIndicator.updateIndex(_index);
    }

    function showPrevious() as Void {
        _index = _index > 0
            ? _index - 1
            : _cards.size() - 1;
        _pageIndicator.updateIndex(_index);
    }
}
