import Toybox.Lang;

class AreaEntityMenuModel {
    public var title as String;
    public var lights as Array<LightRowModel>;
    public var sensors as Array<SensorRowModel>;

    function initialize(title as String, lights as Array<LightRowModel>,
                        sensors as Array<SensorRowModel>) {
        self.title = title;
        self.lights = lights;
        self.sensors = sensors;
    }
}
