import Toybox.Lang;

// One area's entities, resolved once per rebuild and read by both the area card
// and the floor aggregate. A further domain is an added field.
class AreaEntities {
    public var area as AreaModel;
    public var lights as Array<LightModel>;
    public var sensors as Array<SensorModel>;

    function initialize(area as AreaModel, lights as Array<LightModel>,
                        sensors as Array<SensorModel>) {
        self.area = area;
        self.lights = lights;
        self.sensors = sensors;
    }
}
