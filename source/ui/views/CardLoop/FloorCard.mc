import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// One floor, heading the run of area cards beneath it. Its middle band is a
// sentence about the floor's lights rather than a dot per light, there being too
// many across a whole floor to count at a glance.
class FloorCard extends Card {
    private var _zone as String or Null;
    private var _lights as LightTally;

    function initialize(id as String, name as String, zone as String or Null,
                        readings as Array<CardReading>, lights as LightTally) {
        Card.initialize(id, id, name, readings);
        _zone = zone;
        _lights = lights;
    }

    function draw(dc as Graphics.Dc) as Void {
        drawFrame(dc, _zone);
        drawLightStatus(dc, lightStatus());
    }

    function open(coordinator as Coordinator) as Void {
        coordinator.showFloor(id);
    }

    // "No lights available" covers both a floor with no lights and one whose
    // lights are all unavailable.
    private function lightStatus() as String {
        if (_lights.available == 0) {
            return WatchUi.loadResource(Rez.Strings.FloorLightsNone) as String;
        }

        if (_lights.on == _lights.available) {
            return WatchUi.loadResource(Rez.Strings.FloorLightsAllOn) as String;
        }

        if (_lights.on > 0) {
            return WatchUi.loadResource(Rez.Strings.FloorLightsSomeOn) as String;
        }

        return WatchUi.loadResource(Rez.Strings.FloorLightsAllOff) as String;
    }
}
