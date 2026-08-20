import Toybox.Lang;

module EntitySorter {

    const SENSOR_DEVICE_CLASSES = ["temperature", "humidity", "illuminance"] as Array<String>;

    // Sorts a copy: sort mutates in place, and a caller's array is not this
    // module's to reorder.
    function sortAreas(areas as Array<AreaModel>) as Array<AreaModel> {
        var sorted = areas.slice(0, null);
        sorted.sort(new LabelComparator());

        return sorted;
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
        var sorted = lights.slice(0, null);
        sorted.sort(new LabelComparator());

        return sorted;
    }
}
