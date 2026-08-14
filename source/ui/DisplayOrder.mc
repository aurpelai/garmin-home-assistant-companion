import Toybox.Lang;

// The order entities appear in on screen, which is ours rather than Home
// Assistant's: renaming a light changes its place in this list while nothing in
// the house moves. Floor and area order is the home's own and stays in HaState.
module DisplayOrder {

    // Carried over from the template that used to emit sensors already grouped.
    const SENSOR_DEVICE_CLASSES = ["temperature", "humidity", "illuminance"] as Array<String>;

    // By name, dropping any id the structure does not know: a floor's area list
    // can name an area the areas section never reported.
    function orderAreaIds(haState as HaState, areaIds as Array<String>) as Array<String> {
        var known = [] as Array<String>;
        var labels = [] as Array<String>;

        for (var index = 0; index < areaIds.size(); index++) {
            var area = haState.getArea(areaIds[index]);
            if (area == null) {
                continue;
            }

            known.add(areaIds[index]);
            labels.add(area.name == null ? areaIds[index] : area.name as String);
        }

        return orderByLabel(known, labels);
    }

    // Available first, then groups, then by name. Groups lead because they
    // aggregate several lights, so they read as the area's primary controls.
    function orderLightIds(haState as HaState, entityIds as Array<String>) as Array<String> {
        var available = [] as Array<String>;
        var unavailable = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            var light = haState.getLight(entityIds[index]);
            if (light != null && !light.available) {
                unavailable.add(entityIds[index]);
            } else {
                available.add(entityIds[index]);
            }
        }

        var ordered = orderGroupsFirst(haState, available);
        ordered.addAll(orderGroupsFirst(haState, unavailable));
        return ordered;
    }

    // Same device class contiguous, in the order the classes are listed above;
    // a class not listed trails, keeping its input order.
    function groupSensorIdsByDeviceClass(haState as HaState, entityIds as Array<String>) as Array<String> {
        var ordered = [] as Array<String>;
        var claimed = {} as Dictionary<String, Boolean>;

        for (var classIndex = 0; classIndex < SENSOR_DEVICE_CLASSES.size(); classIndex++) {
            var deviceClass = SENSOR_DEVICE_CLASSES[classIndex];

            for (var index = 0; index < entityIds.size(); index++) {
                var sensor = haState.getSensor(entityIds[index]);
                if (sensor != null && deviceClass.equals(sensor.deviceClass)) {
                    ordered.add(entityIds[index]);
                    claimed.put(entityIds[index], true);
                }
            }
        }

        for (var index = 0; index < entityIds.size(); index++) {
            if (!claimed.hasKey(entityIds[index])) {
                ordered.add(entityIds[index]);
            }
        }

        return ordered;
    }

    function orderGroupsFirst(haState as HaState, entityIds as Array<String>) as Array<String> {
        var groups = [] as Array<String>;
        var plain = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            var light = haState.getLight(entityIds[index]);
            if (light != null && light.memberIds != null) {
                groups.add(entityIds[index]);
            } else {
                plain.add(entityIds[index]);
            }
        }

        var ordered = orderByLightName(haState, groups);
        ordered.addAll(orderByLightName(haState, plain));
        return ordered;
    }

    function orderByLightName(haState as HaState, entityIds as Array<String>) as Array<String> {
        var labels = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            var light = haState.getLight(entityIds[index]);
            labels.add(light == null || light.name == null ? entityIds[index] : light.name as String);
        }

        return orderByLabel(entityIds, labels);
    }

    // Sort key is `lowercased-label \n id`: the newline sorts below any printable
    // character, so equal labels fall back to the unique id. toLower is ASCII-only,
    // so non-Latin labels order by code point rather than locale collation.
    function orderByLabel(ids as Array<String>, labels as Array<String>) as Array<String> {
        var idForKey = {} as Dictionary<String, String>;
        var keys = [] as Array<String>;

        for (var index = 0; index < ids.size(); index++) {
            var key = labels[index].toLower() + "\n" + ids[index];
            idForKey.put(key, ids[index]);
            keys.add(key);
        }

        keys.sort(null);

        var ordered = [] as Array<String>;
        for (var index = 0; index < keys.size(); index++) {
            ordered.add(idForKey.get(keys[index]) as String);
        }

        return ordered;
    }
}
