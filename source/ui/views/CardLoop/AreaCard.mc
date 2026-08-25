import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class AreaCard extends Card {
    private const LIGHT_INDICATOR_GAP = 4;

    private const LIGHTBULB_ON = WatchUi.loadResource(Rez.Drawables.LightbulbOn) as WatchUi.BitmapResource;
    private const LIGHTBULB_OFF = WatchUi.loadResource(Rez.Drawables.LightbulbOff) as WatchUi.BitmapResource;
    private const LIGHTBULB_UNAVAILABLE = WatchUi.loadResource(Rez.Drawables.LightbulbUnavailable) as WatchUi.BitmapResource;

    private var _floorName as String or Null;
    private var _lights as LightTally;

    function initialize(id as String, floorId as String or Null, name as String,
                        floorName as String or Null, readings as Array<SensorReading>,
                        lights as LightTally) {
        Card.initialize(id, floorId, name, readings);
        _floorName = floorName;
        _lights = lights;
    }

    function draw(dc as Graphics.Dc) as Void {
        drawFrame(dc, _floorName);

        if (_lights.available + _lights.unavailable > 0) {
            drawLightIndicators(dc, _lights);
        }
    }

    function open(coordinator as Coordinator) as Void {
        coordinator.showAreaMenu(id);
    }

    private function drawLightIndicators(dc as Graphics.Dc, lights as LightTally) as Void {
        var totalCount = lights.available + lights.unavailable;
        var step = LIGHTBULB_ON.getWidth() + LIGHT_INDICATOR_GAP;
        var firstX = dc.getWidth() / 2 - (totalCount - 1) * step / 2;
        var centerY = dc.getHeight() / 2;

        for (var index = 0; index < totalCount; index++) {
            var x = firstX + index * step;

            if (index < lights.on) {
                drawLightIcon(dc, x, centerY, LIGHTBULB_ON, Graphics.COLOR_YELLOW);
            } else if (index < lights.available) {
                drawLightIcon(dc, x, centerY, LIGHTBULB_OFF, Graphics.COLOR_LT_GRAY);
            } else {
                drawLightIcon(dc, x, centerY, LIGHTBULB_UNAVAILABLE, Graphics.COLOR_DK_GRAY);
            }
        }
    }
}
