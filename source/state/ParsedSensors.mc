import Toybox.Lang;

class ParsedSensors {
    public var sensors as Dictionary<String, SensorModel>;
    public var sensorIdsByArea as Dictionary<String, Array<String>>;

    function initialize(sensors as Dictionary<String, SensorModel>,
                        sensorIdsByArea as Dictionary<String, Array<String>>) {
        self.sensors = sensors;
        self.sensorIdsByArea = sensorIdsByArea;
    }
}
