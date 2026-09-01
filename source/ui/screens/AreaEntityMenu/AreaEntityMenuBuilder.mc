import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState. Every
// sublabel is resolved here to the exact string the row shows.
module AreaEntityMenuBuilder {

    function build(haState as HaState, areaId as String,
                   provider as SubLabelProvider) as AreaEntityMenuModel or Null {
        var area = haState.getArea(areaId);
        if (area == null) {
            return null;
        }

        var toggles = buildToggleRows(haState.getLightsInArea(areaId) as Array<ToggleableModel>, provider);
        toggles.addAll(buildToggleRows(haState.getFansInArea(areaId) as Array<ToggleableModel>, provider));

        return new AreaEntityMenuModel(area.name, toggles,
            buildSensorRows(haState.getSensorsInArea(areaId), provider));
    }

    function buildToggleRows(toggleables as Array<ToggleableModel>,
                             provider as SubLabelProvider) as Array<ToggleRowModel> {
        var sorted = EntitySorter.sortToggleables(toggleables);
        var rows = [] as Array<ToggleRowModel>;

        for (var index = 0; index < sorted.size(); index++) {
            var toggleable = sorted[index];
            rows.add(new ToggleRowModel(toggleable.id, toggleable.name, toggleable.isOn(),
                resolveToggleSubLabel(toggleable, provider)));
        }

        return rows;
    }

    function buildSensorRows(sensors as Array<SensorModel>,
                             provider as SubLabelProvider) as Array<SensorRowModel> {
        var grouped = EntitySorter.groupSensorsByDeviceClass(sensors);
        var rows = [] as Array<SensorRowModel>;

        for (var index = 0; index < grouped.size(); index++) {
            var sensor = grouped[index];
            rows.add(new SensorRowModel(sensor.id, sensor.name, resolveSensorSubLabel(sensor, provider)));
        }

        return rows;
    }

    function resolveToggleSubLabel(toggleable as ToggleableModel,
                                   provider as SubLabelProvider) as String or Null {
        var memberIds = toggleable.memberIds;

        if (!toggleable.available) {
            return memberIds == null ? provider.getUnavailable() : provider.getGroupUnavailable();
        }

        if (memberIds != null) {
            return provider.getGroupCount(toggleable instanceof FanModel ? "fan" : "light", memberIds.size());
        }

        if (!toggleable.isOn()) {
            return provider.getOff();
        }

        return toggleable instanceof FanModel
            ? (toggleable as FanModel).speed
            : (toggleable as LightModel).brightness;
    }

    function resolveSensorSubLabel(sensor as SensorModel, provider as SubLabelProvider) as String {
        return sensor.available ? sensor.friendlyState : provider.getUnavailable();
    }
}
