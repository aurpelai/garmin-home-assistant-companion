import Toybox.Lang;

class ParsedLights {
    public var lights as Dictionary<String, LightModel>;
    public var lightIdsByArea as Dictionary<String, Array<String>>;

    function initialize(lights as Dictionary<String, LightModel>,
                        lightIdsByArea as Dictionary<String, Array<String>>) {
        self.lights = lights;
        self.lightIdsByArea = lightIdsByArea;
    }
}
