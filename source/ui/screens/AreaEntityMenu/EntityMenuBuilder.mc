import Toybox.Lang;

module EntityMenuBuilder {

    function build(title as String, toggleables as Array<ToggleableModel>, sensors as Array<SensorModel>,
                   subLabelProvider as SubLabelProvider) as EntityMenuModel {
        return new EntityMenuModel(title, buildEntityRows(toggleables, sensors, subLabelProvider));
    }

    // Toggle rows come out domain by domain in the order each domain first
    // appears, and sorted within each — the caller (an area or a watched-label
    // pool) fixes that order by handing lights before fans.
    function buildEntityRows(toggleables as Array<ToggleableModel>, sensors as Array<SensorModel>,
                             subLabelProvider as SubLabelProvider) as Array<MenuRowModel> {
        var rows = [] as Array<MenuRowModel>;
        var domains = listDomains(toggleables);

        for (var index = 0; index < domains.size(); index++) {
            rows.addAll(buildToggleRows(filterInDomain(toggleables, domains[index]), subLabelProvider));
        }

        rows.addAll(buildSensorRows(sensors, subLabelProvider));

        return rows;
    }

    function buildToggleRows(toggleables as Array<ToggleableModel>,
                             subLabelProvider as SubLabelProvider) as Array<MenuRowModel> {
        toggleables = EntitySorter.sortToggleables(toggleables);
        var rows = [] as Array<MenuRowModel>;

        for (var index = 0; index < toggleables.size(); index++) {
            var toggleable = toggleables[index];
            rows.add(new ToggleRowModel(toggleable.id, toggleable.name, toggleable.isOn(),
                resolveToggleSubLabel(toggleable, subLabelProvider)));
        }

        return rows;
    }

    function listDomains(toggleables as Array<ToggleableModel>) as Array<String> {
        var domains = [] as Array<String>;

        for (var index = 0; index < toggleables.size(); index++) {
            if (domains.indexOf(toggleables[index].domain) < 0) {
                domains.add(toggleables[index].domain);
            }
        }

        return domains;
    }

    function filterInDomain(toggleables as Array<ToggleableModel>, domain as String) as Array<ToggleableModel> {
        var filtered = [] as Array<ToggleableModel>;

        for (var index = 0; index < toggleables.size(); index++) {
            if (toggleables[index].domain.equals(domain)) {
                filtered.add(toggleables[index]);
            }
        }

        return filtered;
    }

    function buildSensorRows(sensors as Array<SensorModel>,
                             subLabelProvider as SubLabelProvider) as Array<MenuRowModel> {
        sensors = EntitySorter.sortSensorsByDeviceClass(sensors);
        var rows = [] as Array<MenuRowModel>;

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
