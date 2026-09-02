import Toybox.Lang;

module EntitySorter {

    // Must match the device classes the sensor template asks Home Assistant for;
    // a class listed only here is never fetched, and one fetched but not listed is
    // never shown.
    const SENSOR_DEVICE_CLASSES = ["temperature", "humidity", "illuminance"] as Array<String>;

    function sortAreas(areas as Array<AreaModel>) as Array<AreaModel> {
        var sorted = areas.slice(0, null);
        sorted.sort(new LabelComparator());

        return sorted;
    }

    function sortToggleables(toggleables as Array<ToggleableModel>) as Array<ToggleableModel> {
        var available = [] as Array<ToggleableModel>;
        var unavailable = [] as Array<ToggleableModel>;

        for (var index = 0; index < toggleables.size(); index++) {
            if (toggleables[index].available) {
                available.add(toggleables[index]);
            } else {
                unavailable.add(toggleables[index]);
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

    function sortGroupsFirst(toggleables as Array<ToggleableModel>) as Array<ToggleableModel> {
        var groups = [] as Array<ToggleableModel>;
        var plain = [] as Array<ToggleableModel>;

        for (var index = 0; index < toggleables.size(); index++) {
            if (toggleables[index].memberIds != null) {
                groups.add(toggleables[index]);
            } else {
                plain.add(toggleables[index]);
            }
        }

        var sorted = sortByName(groups);
        sorted.addAll(sortByName(plain));
        return sorted;
    }

    function sortByName(toggleables as Array<ToggleableModel>) as Array<ToggleableModel> {
        var sorted = toggleables.slice(0, null);
        sorted.sort(new LabelComparator());

        return sorted;
    }
}
