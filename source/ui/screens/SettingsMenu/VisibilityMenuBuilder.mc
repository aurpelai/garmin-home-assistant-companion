import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState. Unlike the
// card loop it lists everything, hidden included, because hiding is only undone
// from here.
module VisibilityMenuBuilder {

    function build(haState as HaState) as Array<VisibilityRowModel> {
        var floors = haState.getFloors();
        var rows = [] as Array<VisibilityRowModel>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            var areas = EntitySorter.sortAreas(haState.getAreasInFloor(floor.id));

            if (areas.size() > 0) {
                rows.add(new FloorVisibilityRowModel(floor.id, floor.name, areas.size(),
                    !haState.getHiddenFloors().hasKey(floor.id)));
                rows.addAll(buildAreaRows(haState, areas));
            }
        }

        rows.addAll(buildAreaRows(haState, EntitySorter.sortAreas(haState.getUnflooredAreas())));

        return rows;
    }

    function buildAreaRows(haState as HaState, areas as Array<AreaModel>) as Array<VisibilityRowModel> {
        var rows = [] as Array<VisibilityRowModel>;

        for (var index = 0; index < areas.size(); index++) {
            var area = areas[index];
            rows.add(new AreaVisibilityRowModel(area.id, area.name, !haState.getHiddenAreas().hasKey(area.id)));
        }

        return rows;
    }
}
