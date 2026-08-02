import Toybox.Lang;

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
            :sensorSummary => buildFloorSensorSummary(session, areaNames)
        };
    }

    // Per-light dot counts for the area card, skipping group entities — HA marks
    // a group on when any member is on, so counting groups would double-count.
    // A light is available or unavailable per server truth; on is counted only
    // among available lights. Null when the area has no non-group lights.
    function buildAreaLightSummary(session as HomeSession, name as String) as Dictionary or Null {
        var lights = session.listLightsInArea(name);
        var lightCount = 0;
        var availableCount = 0;
        var unavailableCount = 0;
        var onCount = 0;

        for (var index = 0; index < lights.size(); index++) {
            var light = lights[index];

            if (session.isGroup(light)) {
                continue;
            }

            lightCount++;

            if (session.isAvailable(light)) {
                availableCount++;

                if (session.isOn(light)) {
                    onCount++;
                }
            } else {
                unavailableCount++;
            }
        }

        if (lightCount == 0) {
            return null;
        }

        return {
            :on => onCount,
            :available => availableCount,
            :unavailable => unavailableCount
        };
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

            if (kind == null || seenKinds.hasKey(kind)) {
                continue;
            }

            var reading = session.getReading(entityId);

            if (reading == null) {
                continue;
            }

            seenKinds.put(kind, true);
            summary.add({
                :kind => kind,
                :reading => reading
            });
        }

        return summary;
    }

    // The mean reading per kind across every sensor of that kind in the floor's
    // areas, formatted to one decimal place and suffixed with the kind's unit.
    // Readings with no numeric value are skipped; a kind with nothing left to
    // average is omitted. One entry per kind: { :kind => String, :reading => String }.
    function buildFloorSensorSummary(session as HomeSession, areaNames as Array<String>) as Array<Dictionary> {
        var kindOrder = [] as Array<String>;
        var readingsByKind = {} as Dictionary<String, Array<Dictionary> >;

        for (var areaIndex = 0; areaIndex < areaNames.size(); areaIndex++) {
            var sensors = session.listSensorsInArea(areaNames[areaIndex]);

            for (var sensorIndex = 0; sensorIndex < sensors.size(); sensorIndex++) {
                var entityId = sensors[sensorIndex];
                var kind = session.getKind(entityId);
                var value = session.getReadingValue(entityId);
                var unit = session.getReadingUnit(entityId);

                if (kind == null || value == null) {
                    continue;
                }

                if (!readingsByKind.hasKey(kind)) {
                    readingsByKind.put(kind, [] as Array<Dictionary>);
                    kindOrder.add(kind);
                }

                (readingsByKind.get(kind) as Array<Dictionary>).add({
                    :value => value,
                    :unit => unit
                });
            }
        }

        var summary = [] as Array<Dictionary>;

        for (var index = 0; index < kindOrder.size(); index++) {
            var kind = kindOrder[index];
            var reading = buildMean(readingsByKind.get(kind) as Array<Dictionary>);

            if (reading == null) {
                continue;
            }

            summary.add({
                :kind => kind,
                :reading => reading
            });
        }

        return summary;
    }

    function buildMean(readings as Array<Dictionary>) as String or Null {
        if (readings.size() == 0) {
            return null;
        }

        var sum = 0.0;

        for (var index = 0; index < readings.size(); index++) {
            sum += readings[index].get(:value) as Float;
        }

        var mean = sum / readings.size();
        var unit = readings[0].get(:unit) as String or Null;
        var formatted = mean.format("%.1f");

        if (unit == null || unit.length() == 0) {
            return formatted;
        }

        return formatted + " " + unit;
    }
}
