import Toybox.Lang;

class AreaModel {
    public var name as String or Null;
    public var lights as Array<String>;
    public var sensors as Array<String>;

    function initialize(name as String or Null, lights as Array<String>, sensors as Array<String>) {
        self.name = name;
        self.lights = lights;
        self.sensors = sensors;
    }
}
