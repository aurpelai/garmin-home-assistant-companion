import Rez.Styles;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class CardLoopView extends WatchUi.View {
    private const SLIDE_SECONDS = 0.75;
    private const HOLD_MS = 2000;
    private const CROSSFADE_SECONDS = 0.05;

    private const SEATED_X = 0;
    private const CROSSFADE_BRIGHT = 1.0;
    private const CROSSFADE_DIM = 0.0;

    private var _session as HomeSession;
    private var _cards as Array<Dictionary>;
    private var _index as Number;
    private var _renderer as CardRenderer;

    private var _reveal as PageIndicatorReveal;
    private var _indicator as PageIndicatorLayer;
    private var _holdTimer as Timer.Timer;

    private var _hiddenX as Number;
    private var _layerAdded as Boolean;

    public var _slideX as Number;
    public var _crossfadeFraction as Float;
    private var _fromIndex as Number;

    // cancelAllAnimations() invokes the cancelled slide's completion callback
    // synchronously; the epoch stamp lets a superseded callback detect that and no-op.
    private var _epoch as Number;
    private var _slideEpoch as Number;

    function initialize(session as HomeSession) {
        View.initialize();
        _session = session;
        _cards = [] as Array<Dictionary>;
        _index = 0;
        _renderer = new CardRenderer();

        _reveal = new PageIndicatorReveal();
        _indicator = new PageIndicatorLayer();
        _holdTimer = new Timer.Timer();

        _hiddenX = 0;
        _layerAdded = false;

        _slideX = 0;
        _crossfadeFraction = CROSSFADE_BRIGHT;
        _fromIndex = 0;

        _epoch = 0;
        _slideEpoch = 0;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        if (!_layerAdded) {
            addLayer(_indicator.getLayer());
            _layerAdded = true;
        }

        _hiddenX = -(dc.getWidth() / 2);
        _slideX = _hiddenX;
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        redraw();
        reveal();
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

        WatchUi.requestUpdate();
        revealOnPageChange();
    }

    function showPrevious() as Void {
        _fromIndex = _index;
        _index = _index > 0 ? _index - 1 : _cards.size() - 1;

        WatchUi.requestUpdate();
        revealOnPageChange();
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

        if (_reveal.isVisible()) {
            _indicator.setLocation(_slideX, 0);
            _indicator.draw(_index, _cards.size(), _crossfadeFraction, _fromIndex);
        }
    }

    function onHide() as Void {
        View.onHide();
        _epoch++;
        WatchUi.cancelAllAnimations();
        _holdTimer.stop();
        _reveal.onRetracted();
        _indicator.setVisible(false);
    }

    private function reveal() as Void {
        if (!show()) {
            return;
        }

        _crossfadeFraction = CROSSFADE_BRIGHT;
    }

    private function revealOnPageChange() as Void {
        if (!show()) {
            return;
        }

        _crossfadeFraction = CROSSFADE_DIM;
        WatchUi.animate(self, :_crossfadeFraction, WatchUi.ANIM_TYPE_LINEAR,
                        CROSSFADE_DIM, CROSSFADE_BRIGHT, CROSSFADE_SECONDS, null);
    }

    private function show() as Boolean {
        _reveal.onTrigger(_cards.size());

        if (!_reveal.isVisible()) {
            _indicator.setVisible(false);
            return false;
        }

        _epoch++;
        WatchUi.cancelAllAnimations();
        _holdTimer.stop();

        _slideX = SEATED_X;
        _indicator.setVisible(true);
        WatchUi.requestUpdate();

        _holdTimer.start(method(:onHoldExpired), HOLD_MS, false);

        return true;
    }

    function onHoldExpired() as Void {
        _epoch++;
        _slideEpoch = _epoch;
        WatchUi.animate(self, :_slideX, WatchUi.ANIM_TYPE_EASE_IN, _slideX, _hiddenX,
                        SLIDE_SECONDS, method(:onRetracted));
    }

    function onRetracted() as Void {
        if (_epoch != _slideEpoch) {
            return;
        }

        _reveal.onRetracted();
        _indicator.setVisible(false);
    }
}
