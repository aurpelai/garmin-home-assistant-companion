import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class FloorCard extends Card {
    private const LIGHTS_ALL = WatchUi.loadResource(Rez.Drawables.LightbulbGroupAll) as WatchUi.BitmapResource;
    private const LIGHTS_SOME = WatchUi.loadResource(Rez.Drawables.LightbulbGroupSome) as WatchUi.BitmapResource;

    private var _zone as String or Null;
    private var _lights as String or Null;

    // A floor is its own floor: passing the id as both is what lets the card loop
    // fall back to the floor when a focused area card disappears.
    function initialize(id as String, name as String, zone as String or Null,
                        readings as Array<SensorReading>, lights as String or Null) {
        Card.initialize(id, id, name, readings);
        _zone = zone;
        _lights = lights;
    }

    function draw(dc as Graphics.Dc) as Void {
        drawFrame(dc, _zone);

        if (_lights != null) {
            drawLightSummary(dc, _lights);
        }
    }

    function open(coordinator as Coordinator) as Void {
        coordinator.showFloorMenu(id);
    }

    private function drawLightSummary(dc as Graphics.Dc, summary as String) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        if (summary.equals(GlanceSummary.ALL_ON)) {
            drawLightIcon(dc, centerX, centerY, LIGHTS_ALL, Graphics.COLOR_YELLOW);
        } else if (summary.equals(GlanceSummary.SOME_ON)) {
            drawLightIcon(dc, centerX, centerY, LIGHTS_SOME, Graphics.COLOR_YELLOW);
        } else {
            drawLightIcon(dc, centerX, centerY, LIGHTS_ALL, Graphics.COLOR_LT_GRAY);
        }
    }
}
