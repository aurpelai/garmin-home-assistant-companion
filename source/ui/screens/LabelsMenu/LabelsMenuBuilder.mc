import Toybox.Lang;

module LabelsMenuBuilder {

    const AREALESS_ID = "arealess";

    function build(title as String, haState as HaState, arealessName as String,
                   subLabelProvider as SubLabelProvider) as EntityMenuModel {
        var toggleablesByArea = haState.groupByArea(
            haState.getWatchedToggleables() as Array<EntityModel>, AREALESS_ID);
        var sensorsByArea = haState.groupByArea(
            haState.getWatchedSensors() as Array<EntityModel>, AREALESS_ID);
        var rows = [] as Array<MenuRowModel>;
        var areas = EntitySorter.sortAreas(haState.getAreas());
        var areaIds = {} as Dictionary<String, Boolean>;

        for (var index = 0; index < areas.size(); index++) {
            var area = areas[index];
            areaIds.put(area.id, true);
            rows.addAll(buildAreaRows(new HeaderRowModel(area.id, area.name),
                toggleablesByArea.get(area.id), sensorsByArea.get(area.id), subLabelProvider));
        }

        rows.addAll(buildAreaRows(new HeaderRowModel(AREALESS_ID, arealessName),
            filterArealess(toggleablesByArea, areaIds), filterArealess(sensorsByArea, areaIds),
            subLabelProvider));

        return new EntityMenuModel(title, rows);
    }

    function buildAreaRows(header as HeaderRowModel, toggleables as Array<EntityModel> or Null,
                           sensors as Array<EntityModel> or Null,
                           subLabelProvider as SubLabelProvider) as Array<MenuRowModel> {
        var areaToggleables = (toggleables == null ? [] : toggleables) as Array<ToggleableModel>;
        var areaSensors = (sensors == null ? [] : sensors) as Array<SensorModel>;

        if (areaToggleables.size() == 0 && areaSensors.size() == 0) {
            return [] as Array<MenuRowModel>;
        }

        var rows = [header] as Array<MenuRowModel>;
        rows.addAll(EntityMenuBuilder.buildEntityRows(areaToggleables, areaSensors, subLabelProvider));

        return rows;
    }

    function filterArealess(byArea as Dictionary<String, Array<EntityModel>>,
                            areaIds as Dictionary<String, Boolean>) as Array<EntityModel> {
        var arealess = [] as Array<EntityModel>;
        var keys = byArea.keys();

        for (var index = 0; index < keys.size(); index++) {
            if (!areaIds.hasKey(keys[index])) {
                arealess.addAll(byArea.get(keys[index]) as Array<EntityModel>);
            }
        }

        return arealess;
    }
}
