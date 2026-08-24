import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class AxialLayout {
    private var _anchorX as Float;
    private var _centerY as Number;
    private var _spacing as Number;
    private var _slideDistance as Float;
    private var _slideOutDuration as Float;
    public var offset as Float;

    function initialize(centerX as Number, centerY as Number, radiusStart as Float, radiusEnd as Float,
                        spacing as Number, slideOutDuration as Float) {
        _anchorX = centerX - radiusStart;
        _centerY = centerY;
        _spacing = spacing;
        _slideDistance = radiusEnd - radiusStart;
        _slideOutDuration = slideOutDuration;
        offset = 0.0;
    }

    function reset() as Void {
        offset = 0.0;
    }

    function startDismiss(onHidden as (Method() as Void)) as Void {
        WatchUi.animate(
            self,
            :offset,
            WatchUi.ANIM_TYPE_LINEAR,
            0.0,
            _slideDistance,
            _slideOutDuration,
            onHidden
        );
    }

    function draw(dc as Graphics.Dc, indicator as PageIndicator, start as Number,
                   count as Number, moreBefore as Boolean, moreAfter as Boolean) as Void {
        var x = _anchorX - offset;
        var top = _centerY - (count - 1) * _spacing / 2.0;

        if (moreBefore) {
            indicator.drawOverflowIndicator(dc, x, top - _spacing);
        }

        for (var i = 0; i < count; i++) {
            indicator.drawIndicator(dc, x, top + i * _spacing, start + i);
        }

        if (moreAfter) {
            indicator.drawOverflowIndicator(dc, x, top + count * _spacing);
        }
    }
}
