import Toybox.Lang;

module EntitySorter {

    const SENSOR_DEVICE_CLASSES = ["temperature", "humidity", "illuminance"] as Array<String>;

    function sortAreas(haState as HaState, areaIds as Array<String>) as Array<String> {
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

        return sortByLabel(known, labels);
    }

    function sortLights(haState as HaState, entityIds as Array<String>) as Array<String> {
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

        var sorted = sortGroupsFirst(haState, available);
        sorted.addAll(sortGroupsFirst(haState, unavailable));
        return sorted;
    }

    function groupSensorsByDeviceClass(haState as HaState, entityIds as Array<String>) as Array<String> {
        var grouped = [] as Array<String>;
        var claimed = {} as Dictionary<String, Boolean>;

        for (var classIndex = 0; classIndex < SENSOR_DEVICE_CLASSES.size(); classIndex++) {
            var deviceClass = SENSOR_DEVICE_CLASSES[classIndex];

            for (var index = 0; index < entityIds.size(); index++) {
                var sensor = haState.getSensor(entityIds[index]);
                if (sensor != null && deviceClass.equals(sensor.deviceClass)) {
                    grouped.add(entityIds[index]);
                    claimed.put(entityIds[index], true);
                }
            }
        }

        for (var index = 0; index < entityIds.size(); index++) {
            if (!claimed.hasKey(entityIds[index])) {
                grouped.add(entityIds[index]);
            }
        }

        return grouped;
    }

    function sortGroupsFirst(haState as HaState, entityIds as Array<String>) as Array<String> {
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

        var sorted = sortByLightName(haState, groups);
        sorted.addAll(sortByLightName(haState, plain));
        return sorted;
    }

    function sortByLightName(haState as HaState, entityIds as Array<String>) as Array<String> {
        var labels = [] as Array<String>;

        for (var index = 0; index < entityIds.size(); index++) {
            var light = haState.getLight(entityIds[index]);
            labels.add(light == null || light.name == null ? entityIds[index] : light.name as String);
        }

        return sortByLabel(entityIds, labels);
    }

    // toLower is ASCII-only, so non-Latin labels order by code point rather than
    // locale collation.
    function sortByLabel(ids as Array<String>, labels as Array<String>) as Array<String> {
        var labelById = {} as Dictionary<String, String>;

        for (var index = 0; index < ids.size(); index++) {
            labelById.put(ids[index], labels[index].toLower());
        }

        var sorted = ids.slice(0, null) as Array<String>;
        sorted.sort(new LabelComparator(labelById));
        return sorted;
    }
}
