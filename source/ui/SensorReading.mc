import Toybox.Lang;

class SensorReading {
    public var deviceClass as String;
    public var text as String;

    function initialize(deviceClass as String, text as String) {
        self.deviceClass = deviceClass;
        self.text = text;
    }

    // Several sensors of one device class average, in an area or across a floor:
    // no one of them speaks for the scope, and picking one would show whichever
    // the walk reached first.
    static function buildFromSensors(sensors as Array<SensorModel>) as Array<SensorReading> {
        var readings = [] as Array<SensorReading>;

        for (var classIndex = 0; classIndex < EntitySorter.SENSOR_DEVICE_CLASSES.size(); classIndex++) {
            var deviceClass = EntitySorter.SENSOR_DEVICE_CLASSES[classIndex];
            var usable = [] as Array<SensorModel>;

            for (var index = 0; index < sensors.size(); index++) {
                var sensor = sensors[index];
                if (sensor.available && sensor.value != null
                        && deviceClass.equals(sensor.deviceClass)) {
                    usable.add(sensor);
                }
            }

            if (usable.size() > 0) {
                readings.add(new SensorReading(deviceClass, formatMean(usable)));
            }
        }

        return readings;
    }

    // A lone reading is echoed as Home Assistant sent it. Averaging several
    // rounds to the fewest decimals any of them carried: a mean is no more
    // precise than its coarsest input, so "21.5 °C" with "22 °C" reads "22 °C".
    private static function formatMean(sensors as Array<SensorModel>) as String {
        if (sensors.size() == 1) {
            return sensors[0].friendlyState;
        }

        var sum = 0.0;
        var decimals = sensors[0].displayPrecision;

        for (var index = 0; index < sensors.size(); index++) {
            sum += sensors[index].value as Float;
            var own = sensors[index].displayPrecision;
            decimals = own < decimals ? own : decimals;
        }

        var mean = (sum / sensors.size()).format("%." + decimals.toString() + "f");
        var unit = sensors[0].unit;

        if (unit == null || (unit as String).length() == 0) {
            return mean;
        }

        return mean + " " + unit;
    }
}
