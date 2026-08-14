import Toybox.Lang;

// One device class's reading as a card shows it, with the text already composed:
// Home Assistant's own formatting for a lone sensor, or a mean across several.
class CardReading {
    public var deviceClass as String;
    public var text as String;

    function initialize(deviceClass as String, text as String) {
        self.deviceClass = deviceClass;
        self.text = text;
    }

    // One card's readings, one per device class in display order, over whichever
    // of the given sensors carry a usable value. A device class with none is
    // absent rather than shown as a blank box.
    //
    // An area shows one of its own sensors verbatim; a floor averages, its
    // sensors sitting in different rooms with no one of them speaking for the
    // floor.
    static function forSensors(haState as HaState, entityIds as Array<String>,
                               average as Boolean) as Array<CardReading> {
        var readings = [] as Array<CardReading>;

        for (var classIndex = 0; classIndex < DisplayOrder.SENSOR_DEVICE_CLASSES.size(); classIndex++) {
            var deviceClass = DisplayOrder.SENSOR_DEVICE_CLASSES[classIndex];
            var sensors = [] as Array<SensorModel>;

            for (var index = 0; index < entityIds.size(); index++) {
                var sensor = haState.getSensor(entityIds[index]);
                if (sensor != null && sensor.available && sensor.value != null
                        && deviceClass.equals(sensor.deviceClass)) {
                    sensors.add(sensor);
                }
            }

            if (sensors.size() > 0) {
                readings.add(new CardReading(deviceClass,
                    average ? meanOf(sensors) : sensors[0].displayValue as String));
            }
        }

        return readings;
    }

    // A lone reading is echoed as Home Assistant sent it. Averaging several
    // rounds to the fewest decimals any of them carried: a mean is no more
    // precise than its coarsest input, so "21.5 °C" with "22 °C" reads "22 °C".
    private static function meanOf(sensors as Array<SensorModel>) as String {
        if (sensors.size() == 1) {
            return sensors[0].displayValue as String;
        }

        var sum = 0.0;
        var decimals = decimalsOf(sensors[0]);

        for (var index = 0; index < sensors.size(); index++) {
            sum += sensors[index].value as Float;
            var own = decimalsOf(sensors[index]);
            decimals = own < decimals ? own : decimals;
        }

        var mean = (sum / sensors.size()).format("%." + decimals.toString() + "f");
        var unit = sensors[0].unit;

        if (unit == null || (unit as String).length() == 0) {
            return mean;
        }

        return mean + " " + unit;
    }

    // The unit is stripped off the display value by value rather than guessed at
    // a separator, leaving the numeric part to measure.
    private static function decimalsOf(sensor as SensorModel) as Number {
        var number = withoutSuffix(sensor.displayValue as String, sensor.unit);
        var dot = number.find(".");

        if (dot == null) {
            return 0;
        }

        var fraction = number.substring(dot + 1, number.length());

        return fraction == null ? 0 : countDigits(fraction as String);
    }

    private static function withoutSuffix(text as String, suffix as String or Null) as String {
        if (suffix == null || (suffix as String).length() == 0
                || (suffix as String).length() > text.length()) {
            return text;
        }

        var tail = text.substring(text.length() - (suffix as String).length(), text.length());

        if (tail == null || !(tail as String).equals(suffix)) {
            return text;
        }

        var head = text.substring(0, text.length() - (suffix as String).length());

        return head == null ? text : head as String;
    }

    private static function countDigits(text as String) as Number {
        var chars = text.toCharArray();
        var count = 0;

        for (var index = 0; index < chars.size(); index++) {
            if (chars[index] >= '0' && chars[index] <= '9') {
                count++;
            }
        }

        return count;
    }
}
