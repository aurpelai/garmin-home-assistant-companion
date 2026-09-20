import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class LabelsCard extends Card {
    // Slug ids never contain a hyphen, so this collides with no area or floor id.
    static const LABELS_CARD_ID = "labels-card";

    private const LIGHT_INDICATOR_GAP = 4;

    private const LIGHT_ON = WatchUi.loadResource(Rez.Drawables.LightOn) as WatchUi.BitmapResource;
    private const LIGHT_OFF = WatchUi.loadResource(Rez.Drawables.LightOff) as WatchUi.BitmapResource;
    private const LIGHT_UNAVAILABLE = WatchUi.loadResource(Rez.Drawables.LightUnavailable) as WatchUi.BitmapResource;

    public var lightCount as ToggleableCount;

    function initialize(name as String, readings as Array<SensorReading>, lightCount as ToggleableCount) {
        Card.initialize(LabelsCard.LABELS_CARD_ID, null, name, readings);
        self.lightCount = lightCount;
    }

    function draw(dc as Graphics.Dc) as Void {
        drawFrame(dc, null);

        if (lightCount.available + lightCount.unavailable > 0) {
            drawLightIndicators(dc, lightCount);
        }
    }

    function onSelect(coordinator as Coordinator) as Void {
        coordinator.showLabelsMenu();
    }

    private function drawLightIndicators(dc as Graphics.Dc, lightCount as ToggleableCount) as Void {
        var totalCount = lightCount.available + lightCount.unavailable;
        var step = LIGHT_ON.getWidth() + LIGHT_INDICATOR_GAP;
        var firstX = dc.getWidth() / 2 - (totalCount - 1) * step / 2;
        var centerY = dc.getHeight() / 2;

        for (var index = 0; index < totalCount; index++) {
            var x = firstX + index * step;

            if (index < lightCount.on) {
                drawLightIcon(dc, x, centerY, LIGHT_ON, Graphics.COLOR_YELLOW);
            } else if (index < lightCount.available) {
                drawLightIcon(dc, x, centerY, LIGHT_OFF, Graphics.COLOR_LT_GRAY);
            } else {
                drawLightIcon(dc, x, centerY, LIGHT_UNAVAILABLE, Graphics.COLOR_DK_GRAY);
            }
        }
    }
}
