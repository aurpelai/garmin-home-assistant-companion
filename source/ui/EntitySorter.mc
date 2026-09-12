import Toybox.Lang;

module EntitySorter {

    // Must match the device classes the sensor template asks Home Assistant for;
    // a class listed only here is never fetched, and one fetched but not listed is
    // never shown.
    const SENSOR_DEVICE_CLASSES = ["temperature", "humidity", "illuminance"] as Array<String>;

    function sortAreas(areas as Array<AreaModel>) as Array<AreaModel> {
        var areasByLabel = areas.slice(0, null);
        areasByLabel.sort(new LabelComparator());

        return areasByLabel;
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

        return sortGroupsFirst(available).addAll(sortGroupsFirst(unavailable)) as Array<ToggleableModel>;
    }

    function groupSensorsByDeviceClass(sensors as Array<SensorModel>) as Array<SensorModel> {
        var sensorsByDeviceClass = [] as Array<SensorModel>;

        for (var classIndex = 0; classIndex < SENSOR_DEVICE_CLASSES.size(); classIndex++) {
            var deviceClass = SENSOR_DEVICE_CLASSES[classIndex];

            for (var index = 0; index < sensors.size(); index++) {
                if (deviceClass.equals(sensors[index].deviceClass)) {
                    sensorsByDeviceClass.add(sensors[index]);
                }
            }
        }

        for (var index = 0; index < sensors.size(); index++) {
            if (SENSOR_DEVICE_CLASSES.indexOf(sensors[index].deviceClass) < 0) {
                sensorsByDeviceClass.add(sensors[index]);
            }
        }

        return sensorsByDeviceClass;
    }

    function sortGroupsFirst(toggleables as Array<ToggleableModel>) as Array<ToggleableModel> {
        var groups = [] as Array<ToggleableModel>;
        var physical = [] as Array<ToggleableModel>;

        for (var index = 0; index < toggleables.size(); index++) {
            if (toggleables[index].memberIds != null) {
                groups.add(toggleables[index]);
            } else {
                physical.add(toggleables[index]);
            }
        }

        return sortByLabel(groups).addAll(sortByLabel(physical)) as Array<ToggleableModel>;
    }

    function sortByLabel(toggleables as Array<ToggleableModel>) as Array<ToggleableModel> {
        var toggleablesByLabel = toggleables.slice(0, null);
        toggleablesByLabel.sort(new LabelComparator());

        return toggleablesByLabel;
    }
}
