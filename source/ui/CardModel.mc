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
            :sensorSummary => buildFloorSensorSummary(session, areaNames)
        };
    }

    // Counts individual lights that are on, skipping group entities — HA marks
    // a group on when any member is on, so counting groups would double-count.
    function buildAreaLightSummary(session as HomeSession, name as String) as String or Null {
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
    function buildAreaSensorSummary(session as HomeSession, name as String) as Array<Dictionary> {
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
    // areas, collapsing to a single value when the ends are equal. Readings with
    // no numeric value are skipped; a kind with nothing left to range over is
    // omitted entirely. One entry per kind: { :kind => String, :range => String }.
    function buildFloorSensorSummary(session as HomeSession, areaNames as Array<String>) as Array<Dictionary> {
        var kindOrder = [] as Array<String>;
        var readingsByKind = {} as Dictionary<String, Array<Dictionary> >;

        for (var areaIndex = 0; areaIndex < areaNames.size(); areaIndex++) {
            var sensors = session.listSensorsInArea(areaNames[areaIndex]);
            for (var sensorIndex = 0; sensorIndex < sensors.size(); sensorIndex++) {
                var entityId = sensors[sensorIndex];
                var kind = session.getKind(entityId);
                var reading = session.getReading(entityId);
                var value = session.getReadingValue(entityId);
                if (kind == null || reading == null || value == null) {
                    continue;
                }

                if (!readingsByKind.hasKey(kind as String)) {
                    readingsByKind.put(kind as String, [] as Array<Dictionary>);
                    kindOrder.add(kind as String);
                }
                (readingsByKind.get(kind as String) as Array<Dictionary>).add({
                    :value => value as Float,
                    :display => reading as String
                });
            }
        }

        var summary = [] as Array<Dictionary>;
        for (var index = 0; index < kindOrder.size(); index++) {
            var kind = kindOrder[index];
            var range = buildRange(readingsByKind.get(kind) as Array<Dictionary>);
            if (range != null) {
                summary.add({ :kind => kind, :range => range as String });
            }
        }
        return summary;
    }

    // The min-max range across a kind's readings, using the parsed numeric value
    // for comparison and the HA display string for the visible precision.
    function buildRange(readings as Array<Dictionary>) as String or Null {
        var minValue = null as Float or Null;
        var maxValue = null as Float or Null;
        var minText = "";
        var maxText = "";

        for (var index = 0; index < readings.size(); index++) {
            var reading = readings[index];
            var numericValue = reading.get(:value) as Float or Null;
            var display = reading.get(:display) as String or Null;
            if (numericValue == null || display == null) {
                continue;
            }

            if (minValue == null || numericValue < (minValue as Float)) {
                minValue = numericValue;
                minText = display as String;
            }
            if (maxValue == null || numericValue >= (maxValue as Float)) {
                maxValue = numericValue;
                maxText = display as String;
            }
        }

        if (minValue == null) {
            return null;
        }

        if ((minValue as Float) != (maxValue as Float)) {
            var minDisplay = minText as String;
            var spaceIndex = minDisplay.find(" ") as Number or Null;
            if (spaceIndex != null && (spaceIndex as Number) >= 0) {
                minDisplay = minDisplay.substring(0, spaceIndex as Number);
            }
            return minDisplay + "–" + maxText;
        }
        return maxText;
    }
}
