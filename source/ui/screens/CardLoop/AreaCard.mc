import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class AreaCard extends Card {
    private const LIGHT_INDICATOR_GAP = 4;

    private const LIGHT_ON = WatchUi.loadResource(Rez.Drawables.LightOn) as WatchUi.BitmapResource;
    private const LIGHT_OFF = WatchUi.loadResource(Rez.Drawables.LightOff) as WatchUi.BitmapResource;
    private const LIGHT_UNAVAILABLE = WatchUi.loadResource(Rez.Drawables.LightUnavailable) as WatchUi.BitmapResource;

    private var _floorName as String or Null;
    public var lights as ToggleableCount;

    function initialize(id as String, floorId as String or Null, name as String,
                        floorName as String or Null, readings as Array<SensorReading>,
                        lights as ToggleableCount) {
        Card.initialize(id, floorId, name, readings);
        _floorName = floorName;
        self.lights = lights;
    }

    function draw(dc as Graphics.Dc) as Void {
        drawFrame(dc, _floorName);

        if (lights.available + lights.unavailable > 0) {
            drawLightIndicators(dc, lights);
        }
    }

    function onSelect(coordinator as Coordinator) as Void {
        coordinator.showAreaMenu(id);
    }

    private function drawLightIndicators(dc as Graphics.Dc, lights as ToggleableCount) as Void {
        var totalCount = lights.available + lights.unavailable;
        var step = LIGHT_ON.getWidth() + LIGHT_INDICATOR_GAP;
        var firstX = dc.getWidth() / 2 - (totalCount - 1) * step / 2;
        var centerY = dc.getHeight() / 2;

        for (var index = 0; index < totalCount; index++) {
            var x = firstX + index * step;

            if (index < lights.on) {
                drawLightIcon(dc, x, centerY, LIGHT_ON, Graphics.COLOR_YELLOW);
            } else if (index < lights.available) {
                drawLightIcon(dc, x, centerY, LIGHT_OFF, Graphics.COLOR_LT_GRAY);
            } else {
                drawLightIcon(dc, x, centerY, LIGHT_UNAVAILABLE, Graphics.COLOR_DK_GRAY);
            }
        }
    }
}
