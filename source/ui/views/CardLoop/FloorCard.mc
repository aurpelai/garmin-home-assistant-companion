import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class FloorCard extends Card {
    private var _zone as String or Null;
    private var _lights as LightTally;

    function initialize(id as String, name as String, zone as String or Null,
                        readings as Array<SensorReading>, lights as LightTally) {
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
