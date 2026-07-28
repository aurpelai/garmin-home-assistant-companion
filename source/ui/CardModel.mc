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
                cards.add(buildFloorCard(session, floorName as String, areaNames));
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
            :lightSummary => areaLightSummary(session, name),
            :sensorSummary => areaSensorSummary(session, name)
        };
    }

    function buildFloorCard(session as HomeSession, name as String,
                            areaNames as Array<String>) as Dictionary {
        return {
            :type => :floor,
            :name => name,
            :selectable => false,
            :sensorSummary => floorSensorSummary(session, areaNames)
        };
    }

    // Counts individual lights that are on, skipping group entities — HA marks
    // a group on when any member is on, so counting groups would double-count.
    // Null when the area has no individual lights, so the card omits the row
    // rather than showing "0 lights on".
    function areaLightSummary(session as HomeSession, name as String) as String or Null {
        var lights = session.listLightsInArea(name);
        var lightCount = 0;
        var onCount = 0;
        for (var index = 0; index < lights.size(); index++) {
            var light = lights[index];
            if (session.isGroup(light)) {
                continue;
            }
            lightCount++;
            if (session.isOn(light)) {
                onCount++;
            }
        }
        if (lightCount == 0) {
            return null;
        }
        if (onCount == 1) {
            return WatchUi.loadResource(Rez.Strings.OneLightOn) as String;
        }
        var template = WatchUi.loadResource(Rez.Strings.LightsOn) as String;
        return Lang.format(template, [onCount]);
    }

    // The first readable sensor of each kind present in the area, in the order
    // its kind is first encountered (the template already groups sensors by
    // kind). A sensor with no reading is skipped so a later same-kind sensor can
    // fill the kind. One entry per kind: { :kind => String, :reading => String }.
    function areaSensorSummary(session as HomeSession, name as String) as Array<Dictionary> {
        var sensors = session.listSensorsInArea(name);
        var seenKinds = {} as Dictionary<String, Boolean>;
        var summary = [] as Array<Dictionary>;

        for (var index = 0; index < sensors.size(); index++) {
            var entityId = sensors[index];
            var kind = session.getKind(entityId);
            if (kind == null || seenKinds.hasKey(kind as String)) {
                continue;
            }

            var reading = session.getReading(entityId);
            if (reading == null) {
                continue;
            }

            seenKinds.put(kind as String, true);
            summary.add({ :kind => kind as String, :reading => reading as String });
        }
        return summary;
    }

    // A min-max range per kind across every sensor of that kind in the floor's
    // areas, collapsing to a single value when the ends are equal. A reading
    // that String.toFloat() can't parse a leading number from is skipped; a
    // kind with nothing left to range over is omitted entirely. One entry per
    // kind: { :kind => String, :range => String }.
    function floorSensorSummary(session as HomeSession, areaNames as Array<String>) as Array<Dictionary> {
        var kindOrder = [] as Array<String>;
        var readingsByKind = {} as Dictionary<String, Array<String> >;

        for (var areaIndex = 0; areaIndex < areaNames.size(); areaIndex++) {
            var sensors = session.listSensorsInArea(areaNames[areaIndex]);
            for (var sensorIndex = 0; sensorIndex < sensors.size(); sensorIndex++) {
                var entityId = sensors[sensorIndex];
                var kind = session.getKind(entityId);
                var reading = session.getReading(entityId);
                if (kind == null || reading == null) {
                    continue;
                }

                if (!readingsByKind.hasKey(kind as String)) {
                    readingsByKind.put(kind as String, [] as Array<String>);
                    kindOrder.add(kind as String);
                }
                (readingsByKind.get(kind as String) as Array<String>).add(reading as String);
            }
        }

        var summary = [] as Array<Dictionary>;
        for (var index = 0; index < kindOrder.size(); index++) {
            var kind = kindOrder[index];
            var range = rangeOf(readingsByKind.get(kind) as Array<String>);
            if (range != null) {
                summary.add({ :kind => kind, :range => range as String });
            }
        }
        return summary;
    }

    // The min-max range across a kind's readings, formatted with the unit
    // suffix of the reading that produced the max (min and max share a unit in
    // practice — every reading of a kind comes from the same HA formatter).
    // Unparseable readings (toFloat() == null) are skipped; null when none
    // parse. Collapses to a single value when min == max.
    function rangeOf(readings as Array<String>) as String or Null {
        var minValue = null as Float or Null;
        var maxValue = null as Float or Null;
        var maxSuffix = "";

        for (var index = 0; index < readings.size(); index++) {
            var reading = readings[index];
            var value = reading.toFloat();
            if (value == null) {
                continue;
            }

            var numericValue = value as Float;
            if (minValue == null || numericValue < (minValue as Float)) {
                minValue = numericValue;
            }
            if (maxValue == null || numericValue >= (maxValue as Float)) {
                maxValue = numericValue;
                maxSuffix = suffixOf(reading, numericValue);
            }
        }

        if (minValue == null) {
            return null;
        }
        if ((minValue as Float) == (maxValue as Float)) {
            return formatNumber(minValue as Float) + maxSuffix;
        }
        return formatNumber(minValue as Float) + "–" + formatNumber(maxValue as Float) + maxSuffix;
    }

    // Whatever HA appended after the leading number toFloat() consumed (e.g.
    // " °C" out of "24.6 °C"), found by stripping the parsed value's own
    // rendering off the front of the reading. Falls back to the raw reading
    // (minus nothing) only if the value re-renders differently than HA's
    // formatting — in practice HA's leading-number text always matches.
    function suffixOf(reading as String, value as Float) as String {
        // Longer, more specific candidate first: "23.0" must be tried before
        // "23", or the bare integer would match as a false-positive prefix of
        // "23.0 °C" and leave ".0" stuck onto the suffix.
        var candidates = [value.format("%.1f"), value.toNumber() + ""] as Array<String>;
        for (var index = 0; index < candidates.size(); index++) {
            var prefix = candidates[index];
            if (reading.length() >= prefix.length() &&
                    (reading.substring(0, prefix.length()) as String).equals(prefix)) {
                return reading.substring(prefix.length(), reading.length()) as String;
            }
        }
        return "";
    }

    // Trims a trailing ".0" so a whole-number range reads "19" rather than
    // "19.0", while a genuine fraction like "19.5" is preserved.
    function formatNumber(value as Float) as String {
        if (value == value.toNumber()) {
            return value.toNumber() + "";
        }
        return value.format("%.1f");
    }
}
