import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class FloorCard extends Card {
    private const LIGHTS_ALL = WatchUi.loadResource(Rez.Drawables.LightbulbGroup) as WatchUi.BitmapResource;
    private const LIGHTS_SOME = WatchUi.loadResource(Rez.Drawables.LightbulbGroupOutline) as WatchUi.BitmapResource;

    private var _zone as String or Null;
    private var _lights as LightTally;

    // A floor is its own floor: passing the id as both is what lets the card loop
    // fall back to the floor when a focused area card disappears.
    function initialize(id as String, name as String, zone as String or Null,
                        readings as Array<SensorReading>, lights as LightTally) {
        Card.initialize(id, id, name, readings);
        _zone = zone;
        _lights = lights;
    }

    function draw(dc as Graphics.Dc) as Void {
        drawFrame(dc, _zone);

        if (_lights.available + _lights.unavailable > 0) {
            drawLightSummary(dc);
        }
    }

    function open(coordinator as Coordinator) as Void {
        coordinator.showFloorMenu(id);
    }

    private function drawLightSummary(dc as Graphics.Dc) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        if (_lights.on == _lights.available && _lights.on > 0) {
            drawLightIcon(dc, centerX, centerY, LIGHTS_ALL, Graphics.COLOR_YELLOW);
        } else if (_lights.on > 0) {
            drawLightIcon(dc, centerX, centerY, LIGHTS_SOME, Graphics.COLOR_YELLOW);
        } else {
            drawLightIcon(dc, centerX, centerY, LIGHTS_ALL, Graphics.COLOR_LT_GRAY);
        }
    }
}
