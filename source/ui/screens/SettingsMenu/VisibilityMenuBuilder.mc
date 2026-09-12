import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState. Unlike the
// card loop it lists everything, hidden included, because hiding is only undone
// from here.
module VisibilityMenuBuilder {

    function build(haState as HaState, unflooredName as String) as Array<VisibilityRowModel> {
        var floors = haState.getFloors();
        var rows = [] as Array<VisibilityRowModel>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            rows.addAll(buildFloorRows(haState, floor.id, floor.name, haState.getAreasInFloor(floor.id)));
        }

        rows.addAll(buildFloorRows(haState, VisibilityStore.UNFLOORED_FLOOR_ID, unflooredName,
            haState.getUnflooredAreas()));

        return rows;
    }

    function buildFloorRows(haState as HaState, floorId as String, floorName as String,
                            areas as Array<AreaModel>) as Array<VisibilityRowModel> {
        if (areas.size() == 0) {
            return [] as Array<VisibilityRowModel>;
        }

        var rows = [new FloorVisibilityRowModel(floorId, floorName, areas.size(),
            !haState.getHiddenFloors().hasKey(floorId))] as Array<VisibilityRowModel>;
        rows.addAll(buildAreaRows(haState, EntitySorter.sortAreas(areas)));

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
