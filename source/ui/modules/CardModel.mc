import Toybox.Lang;
import Toybox.WatchUi;

// Pure session -> card-dictionary functions behind the card loop's view. No
// drawing; the view (CardLoopView) owns state, paging, and rendering.
module CardModel {

    // Walks the session's grouped floor structure into a flat card sequence:
    // for each floor group, a floor card (skipped when :name is null — the
    // trailing unfloored bucket has no header) followed by its area cards.
    function buildCards(session as HomeSession) as Array<Dictionary> {
        var cards = [] as Array<Dictionary>;
        var groups = session.buildFloorGroups();

        for (var groupIndex = 0; groupIndex < groups.size(); groupIndex++) {
            var group = groups[groupIndex];
            var floorName = group.get(:name) as String or Null;
            var areaNames = group.get(:areas) as Array<String>;

            if (floorName != null) {
                cards.add(buildFloorCard(session, floorName, areaNames));
            }

            for (var areaIndex = 0; areaIndex < areaNames.size(); areaIndex++) {
                cards.add(buildAreaCard(session, areaNames[areaIndex], floorName));
            }
        }

        return cards;
    }

    function buildAreaCard(session as HomeSession, name as String,
                           floorName as String or Null) as Dictionary {
        return {
            :type => :area,
            :name => name,
            :floor => floorName,
            :selectable => true,
            :lightSummary => buildAreaLightSummary(session, name),
            :sensorSummary => buildAreaSensorSummary(session, name)
        };
    }

    function buildFloorCard(session as HomeSession, name as String,
                            areaNames as Array<String>) as Dictionary {
        return {
            :type => :floor,
            :name => name,
            :selectable => false,
            :lightSummary => buildFloorLightSummary(session, areaNames),
            :sensorSummary => buildFloorSensorSummary(session, areaNames)
        };
    }

    function buildAreaLightSummary(session as HomeSession, name as String) as HomeSession.LightStates or Null {
        var states = session.getLightStates(session.listLightsInArea(name));

        if ((states.get(:available) as Number) + (states.get(:unavailable) as Number) == 0) {
            return null;
        }

        return states;
    }

    // A glanceable line summarizing a whole floor's lights, judged among its
    // available lights only. "No lights available" covers both a floor with no
    // lights and one whose lights are all unavailable.
    function buildFloorLightSummary(session as HomeSession, areaNames as Array<String>) as String {
        var states = session.getFloorLightStates(areaNames);
        var onCount = states.get(:on) as Number;
        var availableCount = states.get(:available) as Number;

        if (availableCount == 0) {
            return WatchUi.loadResource(Rez.Strings.FloorLightsNone) as String;
        }

        if (onCount == availableCount) {
            return WatchUi.loadResource(Rez.Strings.FloorLightsAllOn) as String;
        }

        if (onCount > 0) {
            return WatchUi.loadResource(Rez.Strings.FloorLightsSomeOn) as String;
        }

        return WatchUi.loadResource(Rez.Strings.FloorLightsAllOff) as String;
    }

    // For now each kind shows its first sensor's reading as-is; moving to a
    // mean/range/list later is a change here, not in the session, which hands
    // over every sensor untouched.
    function buildAreaSensorSummary(session as HomeSession, name as String) as Array<Dictionary> {
        var groups = groupReadingsByKind(session.getAreaReadings(name));
        var summary = [] as Array<Dictionary>;

        for (var index = 0; index < groups.size(); index++) {
            var group = groups[index];

            summary.add({
                :kind => group.get(:kind) as String,
                :reading => (group.get(:readings) as Array<HomeSession.SensorReading>)[0].get(:display) as String
            });
        }

        return summary;
    }

    function buildFloorSensorSummary(session as HomeSession, areaNames as Array<String>) as Array<Dictionary> {
        var groups = groupReadingsByKind(session.getFloorReadings(areaNames));
        var summary = [] as Array<Dictionary>;

        for (var index = 0; index < groups.size(); index++) {
            var group = groups[index];

            summary.add({
                :kind => group.get(:kind) as String,
                :reading => calculateMeanReading(group.get(:readings) as Array<HomeSession.SensorReading>)
            });
        }

        return summary;
    }

    // Readings grouped by kind, in first-seen kind order, as an ordered list of
    // { :kind => String, :readings => Array<SensorReading> }.
    function groupReadingsByKind(readings as Array<HomeSession.SensorReading>) as Array<Dictionary> {
        var groups = [] as Array<Dictionary>;
        var indexByKind = {} as Dictionary<String, Number>;

        for (var index = 0; index < readings.size(); index++) {
            var reading = readings[index];
            var kind = reading.get(:kind) as String;

            if (!indexByKind.hasKey(kind)) {
                indexByKind.put(kind, groups.size());
                groups.add({ :kind => kind, :readings => [] as Array<HomeSession.SensorReading> });
            }

            (groups[indexByKind.get(kind) as Number].get(:readings) as Array<HomeSession.SensorReading>).add(reading);
        }

        return groups;
    }

    // A single reading is shown as HA sent it. Averaging several rounds to the
    // fewest decimals any of them carried: a mean is no more precise than its
    // coarsest input, so "21.5 °C" combined with "22 °C" reads "22 °C".
    function calculateMeanReading(readings as Array<HomeSession.SensorReading>) as String {
        if (readings.size() == 1) {
            return readings[0].get(:display) as String;
        }

        var sum = 0.0;
        var decimals = decimalsOf(readings[0]);

        for (var index = 0; index < readings.size(); index++) {
            sum += readings[index].get(:value) as Float;
            decimals = min(decimals, decimalsOf(readings[index]));
        }

        var mean = (sum / readings.size()).format("%." + decimals.toString() + "f");
        var unit = readings[0].get(:unit) as String or Null;

        if (unit == null || unit.length() == 0) {
            return mean;
        }

        return mean + " " + unit;
    }

    // Decimal places HA showed for a reading, e.g. 1 for "21.5 °C", 0 for
    // "120 lx". The unit is stripped off the display by value rather than guessed
    // at a separator, leaving the numeric part to measure.
    function decimalsOf(reading as HomeSession.SensorReading) as Number {
        var display = reading.get(:display) as String;
        var unit = reading.get(:unit) as String or Null;
        var number = stripSuffix(display, unit);
        var dot = number.find(".");

        if (dot == null) {
            return 0;
        }

        var fraction = number.substring(dot + 1, number.length());

        return fraction == null ? 0 : countDigits(fraction);
    }

    function stripSuffix(text as String, suffix as String or Null) as String {
        if (suffix == null || suffix.length() == 0 || suffix.length() > text.length()) {
            return text;
        }

        var tail = text.substring(text.length() - suffix.length(), text.length());

        if (tail == null || !tail.equals(suffix)) {
            return text;
        }

        var head = text.substring(0, text.length() - suffix.length());

        return head == null ? text : head;
    }

    function countDigits(text as String) as Number {
        var chars = text.toCharArray();
        var count = 0;

        for (var index = 0; index < chars.size(); index++) {
            if (chars[index] >= '0' && chars[index] <= '9') {
                count++;
            }
        }

        return count;
    }

    function min(a as Number, b as Number) as Number {
        return a < b ? a : b;
    }
}
