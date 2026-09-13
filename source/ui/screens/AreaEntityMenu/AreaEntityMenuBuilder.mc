import Toybox.Lang;

module AreaEntityMenuBuilder {

    function build(haState as HaState, areaId as String,
                   subLabelProvider as SubLabelProvider) as AreaEntityMenuModel or Null {
        var area = haState.getArea(areaId);
        if (area == null) {
            return null;
        }

        var toggles = buildToggleRows(haState.getToggleablesInArea(areaId, Domain.LIGHT), subLabelProvider);
        toggles.addAll(buildToggleRows(haState.getToggleablesInArea(areaId, Domain.FAN), subLabelProvider));

        return new AreaEntityMenuModel(area.name, toggles,
            buildSensorRows(haState.getSensorsInArea(areaId), subLabelProvider));
    }

    function buildToggleRows(toggleables as Array<ToggleableModel>,
                             subLabelProvider as SubLabelProvider) as Array<ToggleRowModel> {
        toggleables = EntitySorter.sortToggleables(toggleables);
        var rows = [] as Array<ToggleRowModel>;

        for (var index = 0; index < toggleables.size(); index++) {
            var toggleable = toggleables[index];
            rows.add(new ToggleRowModel(toggleable.id, toggleable.name, toggleable.isOn(),
                resolveToggleSubLabel(toggleable, subLabelProvider)));
        }

        return rows;
    }

    function buildSensorRows(sensors as Array<SensorModel>,
                             subLabelProvider as SubLabelProvider) as Array<SensorRowModel> {
        sensors = EntitySorter.sortSensorsByDeviceClass(sensors);
        var rows = [] as Array<SensorRowModel>;

        for (var index = 0; index < sensors.size(); index++) {
            var sensor = sensors[index];
            rows.add(new SensorRowModel(sensor.id, sensor.name, resolveSensorSubLabel(sensor, subLabelProvider)));
        }

        return rows;
    }

    function resolveToggleSubLabel(toggleable as ToggleableModel,
                                   subLabelProvider as SubLabelProvider) as String or Null {
        var memberIds = toggleable.memberIds;

        if (!toggleable.available) {
            return memberIds == null ? subLabelProvider.getUnavailable() : subLabelProvider.getGroupUnavailable();
        }

        if (memberIds != null) {
            return subLabelProvider.resolveGroupLabel(toggleable.domain, memberIds.size());
        }

        if (!toggleable.isOn()) {
            return subLabelProvider.getOff();
        }

        var value = toggleable instanceof FanModel
            ? (toggleable as FanModel).resolveSpeed()
            : (toggleable as LightModel).resolveBrightness();

        return value == null ? subLabelProvider.getOn() : subLabelProvider.formatValue(value);
    }

    function resolveSensorSubLabel(sensor as SensorModel, subLabelProvider as SubLabelProvider) as String {
        return sensor.available ? sensor.friendlyState : subLabelProvider.getUnavailable();
    }
}
