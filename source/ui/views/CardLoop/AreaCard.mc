import Toybox.Graphics;
import Toybox.Lang;

// One area. Its middle band is a dot per physical light in the area, so a glance
// says how many are on; an area with no lights at all shows none.
class AreaCard extends Card {
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
}
