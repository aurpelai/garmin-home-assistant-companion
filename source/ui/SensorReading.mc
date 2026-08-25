import Toybox.Lang;

class SensorReading {
    public var deviceClass as String;
    public var text as String;

    function initialize(deviceClass as String, text as String) {
        self.deviceClass = deviceClass;
        self.text = text;
    }

    static function fromMeans(means as Dictionary<String, String>) as Array<SensorReading> {
        var readings = [] as Array<SensorReading>;

        for (var index = 0; index < EntitySorter.SENSOR_DEVICE_CLASSES.size(); index++) {
            var deviceClass = EntitySorter.SENSOR_DEVICE_CLASSES[index];
            var text = means.get(deviceClass);
            if (text != null) {
                readings.add(new SensorReading(deviceClass, text));
            }
        }

        return readings;
    }
}
