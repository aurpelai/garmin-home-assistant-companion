import Rez.Styles;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class CardLoopView extends WatchUi.View {
    private const ANIMATION_DURATION = 0.1;
    private const VISIBLE_DURATION_MS = 1800;
    private const FADE_DURATION = 0.05;

    private var _session as HomeSession;
    private var _cards as Array<Dictionary>;
    private var _index as Number;
    private var _renderer as CardRenderer;

    private var _pageIndicatorState as PageIndicatorState;
    private var _pageIndicator as PageIndicator;
    private var _visibleTimer as Timer.Timer;

    private var _layerAdded as Boolean;

    public var _animationProgress as Float;
    public var _fadeProgress as Float;
    private var _fromIndex as Number;

    // cancelAllAnimations() invokes the cancelled animation's completion callback
    // synchronously; the epoch stamp lets a superseded callback detect that and no-op.
    private var _epoch as Number;
    private var _animationEpoch as Number;

    function initialize(session as HomeSession) {
        View.initialize();
        _session = session;
        _cards = [] as Array<Dictionary>;
        _index = 0;
        _renderer = new CardRenderer();

        _pageIndicatorState = new PageIndicatorState();
        _pageIndicator = new PageIndicator();
        _visibleTimer = new Timer.Timer();

        _layerAdded = false;

        _animationProgress = 0.0;
        _fadeProgress = 1.0;
        _fromIndex = 0;

        _epoch = 0;
        _animationEpoch = 0;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        if (!_layerAdded) {
            addLayer(_pageIndicator.getLayer());
            _layerAdded = true;
        }
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        redraw();
        showIndicator();
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
        _fromIndex = _index;
        _index = _index < _cards.size() - 1 ? _index + 1 : 0;

        if (showIndicator()) {
            fadeActiveDot();
        }
    }

    function showPrevious() as Void {
        _fromIndex = _index;
        _index = _index > 0 ? _index - 1 : _cards.size() - 1;

        if (showIndicator()) {
            fadeActiveDot();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, system_color_dark__background.background);
        dc.clear();

        var card = getCurrentCard();

        if (card == null) {
            CenteredMessage.draw(dc, WatchUi.loadResource(Rez.Strings.NoEntitiesInAnyArea) as String);
            return;
        }

        _renderer.drawCard(dc, card as Dictionary);

        if (_pageIndicatorState.isVisible()) {
            _pageIndicator.draw(_index, _cards.size(), _fadeProgress, _fromIndex, _animationProgress);
        }
    }

    function onHide() as Void {
        View.onHide();
        _epoch++;
        WatchUi.cancelAllAnimations();
        _visibleTimer.stop();
        _pageIndicatorState.onHidden();
        _pageIndicator.clear();
    }

    private function showIndicator() as Boolean {
        _pageIndicatorState.onTrigger(_cards.size());

        if (!_pageIndicatorState.isVisible()) {
            return false;
        }

        _epoch++;
        WatchUi.cancelAllAnimations();
        _visibleTimer.stop();

        _animationProgress = 0.0;
        _fadeProgress = 1.0;
        WatchUi.requestUpdate();

        _visibleTimer.start(method(:hideIndicator), VISIBLE_DURATION_MS, false);

        return true;
    }

    private function fadeActiveDot() as Void {
        _fadeProgress = 0.0;
        WatchUi.animate(self, :_fadeProgress, WatchUi.ANIM_TYPE_LINEAR, 0.0, 1.0,
                        FADE_DURATION, null);
    }

    function hideIndicator() as Void {
        _epoch++;
        _animationEpoch = _epoch;
        WatchUi.animate(self, :_animationProgress, WatchUi.ANIM_TYPE_LINEAR, _animationProgress, 1.0,
                        ANIMATION_DURATION, method(:onIndicatorHide));
    }

    function onIndicatorHide() as Void {
        if (_epoch != _animationEpoch) {
            return;
        }

        _pageIndicatorState.onHidden();
        _pageIndicator.clear();
    }
}
