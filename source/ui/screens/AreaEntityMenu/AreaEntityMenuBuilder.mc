import Toybox.Lang;

module AreaEntityMenuBuilder {

    function build(haState as HaState, areaId as String) as AreaEntityMenuModel or Null {
        var area = haState.getArea(areaId);
        if (area == null) {
            return null;
        }

        var toggles = toToggleRows(haState.getLightsInArea(areaId) as Array<ToggleableModel>);
        toggles.addAll(toToggleRows(haState.getFansInArea(areaId) as Array<ToggleableModel>));

        var groupedSensors = EntitySorter.groupSensorsByDeviceClass(haState.getSensorsInArea(areaId));
        var sensors = [] as Array<SensorRowModel>;

        for (var index = 0; index < groupedSensors.size(); index++) {
            var sensor = groupedSensors[index];
            sensors.add(new SensorRowModel(sensor.id, sensor.name, sensor.friendlyState, sensor.available));
        }

        return new AreaEntityMenuModel(area.name, toggles, sensors);
    }

    function toToggleRows(toggleables as Array<ToggleableModel>) as Array<ToggleRowModel> {
        var sorted = EntitySorter.sortToggleables(toggleables);
        var rows = [] as Array<ToggleRowModel>;

        for (var index = 0; index < sorted.size(); index++) {
            var toggleable = sorted[index];
            var memberIds = toggleable.memberIds;

            rows.add(new ToggleRowModel(
                toggleable.id,
                toggleable.name,
                toggleable.isOn(),
                toggleable.available,
                memberIds == null ? null : memberIds.size(),
                toSubLabel(toggleable)));
        }

        return rows;
    }

    function toSubLabel(toggleable as ToggleableModel) as String or Null {
        return toggleable instanceof FanModel && toggleable.isOn() ? (toggleable as FanModel).speed : null;
    }
}
