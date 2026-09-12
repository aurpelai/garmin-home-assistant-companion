import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState. Unlike the
// card loop it lists everything, hidden included, because hiding is only undone
// from here.
module VisibilityMenuBuilder {

    function build(haState as HaState) as Array<VisibilityToggleRowModel> {
        var floors = haState.getFloors();
        var rows = [] as Array<VisibilityToggleRowModel>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            var areas = EntitySorter.sortAreas(haState.getAreasInFloor(floor.id));

            if (areas.size() > 0) {
                rows.add(new VisibilityToggleRowModel(floor.id, floor.name, true, areas.size(),
                    !haState.getHiddenFloors().hasKey(floor.id)));
                rows.addAll(buildAreaRows(haState, areas));
            }
        }

        rows.addAll(buildAreaRows(haState, EntitySorter.sortAreas(haState.getUnflooredAreas())));

        return rows;
    }

    function buildAreaRows(haState as HaState, areas as Array<AreaModel>) as Array<VisibilityToggleRowModel> {
        var rows = [] as Array<VisibilityToggleRowModel>;

        for (var index = 0; index < areas.size(); index++) {
            var area = areas[index];
            rows.add(new VisibilityToggleRowModel(area.id, area.name, false, 0,
                !haState.getHiddenAreas().hasKey(area.id)));
        }

        return rows;
    }
}
