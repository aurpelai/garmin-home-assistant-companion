import Toybox.Lang;

module EntitySorter {

    const SENSOR_DEVICE_CLASSES = ["temperature", "humidity", "illuminance"] as Array<String>;

    function sortAreas(areas as Array<AreaModel>) as Array<AreaModel> {
        var byId = {} as Dictionary<String, Object>;
        var labels = {} as Dictionary<String, String>;

        for (var index = 0; index < areas.size(); index++) {
            byId.put(areas[index].id, areas[index]);
            labels.put(areas[index].id, areas[index].name.toLower());
        }

        return sortByLabel(byId, labels) as Array<AreaModel>;
    }

    function sortLights(lights as Array<LightModel>) as Array<LightModel> {
        var available = [] as Array<LightModel>;
        var unavailable = [] as Array<LightModel>;

        for (var index = 0; index < lights.size(); index++) {
            if (lights[index].available) {
                available.add(lights[index]);
            } else {
                unavailable.add(lights[index]);
            }
        }

        var sorted = sortGroupsFirst(available);
        sorted.addAll(sortGroupsFirst(unavailable));
        return sorted;
    }

    function groupSensorsByDeviceClass(sensors as Array<SensorModel>) as Array<SensorModel> {
        var grouped = [] as Array<SensorModel>;
        var claimed = {} as Dictionary<String, Boolean>;

        for (var classIndex = 0; classIndex < SENSOR_DEVICE_CLASSES.size(); classIndex++) {
            var deviceClass = SENSOR_DEVICE_CLASSES[classIndex];

            for (var index = 0; index < sensors.size(); index++) {
                if (deviceClass.equals(sensors[index].deviceClass)) {
                    grouped.add(sensors[index]);
                    claimed.put(sensors[index].id, true);
                }
            }
        }

        for (var index = 0; index < sensors.size(); index++) {
            if (!claimed.hasKey(sensors[index].id)) {
                grouped.add(sensors[index]);
            }
        }

        return grouped;
    }

    function sortGroupsFirst(lights as Array<LightModel>) as Array<LightModel> {
        var groups = [] as Array<LightModel>;
        var plain = [] as Array<LightModel>;

        for (var index = 0; index < lights.size(); index++) {
            if (lights[index].memberIds != null) {
                groups.add(lights[index]);
            } else {
                plain.add(lights[index]);
            }
        }

        var sorted = sortByLightName(groups);
        sorted.addAll(sortByLightName(plain));
        return sorted;
    }

    function sortByLightName(lights as Array<LightModel>) as Array<LightModel> {
        var byId = {} as Dictionary<String, Object>;
        var labels = {} as Dictionary<String, String>;

        for (var index = 0; index < lights.size(); index++) {
            byId.put(lights[index].id, lights[index]);
            labels.put(lights[index].id, lights[index].name.toLower());
        }

        return sortByLabel(byId, labels) as Array<LightModel>;
    }

    // Keyed by id internally, which is what identity is for; the comparator
    // breaks equal labels on the id, so the order is total whatever order the
    // keys come back in.
    //
    // The callers lower with toLower, which is ASCII-only, so non-Latin labels
    // order by code point rather than locale collation.
    function sortByLabel(modelsById as Dictionary<String, Object>,
                         labelsById as Dictionary<String, String>) as Array<Object> {
        var ids = modelsById.keys() as Array<String>;
        ids.sort(new LabelComparator(labelsById));

        var sorted = [] as Array<Object>;

        for (var index = 0; index < ids.size(); index++) {
            sorted.add(modelsById.get(ids[index]) as Object);
        }

        return sorted;
    }
}
