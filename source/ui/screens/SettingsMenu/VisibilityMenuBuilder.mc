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
            rows.add(new VisibilityToggleRowModel(floor.id, floor.name, null, true,
                !haState.getHiddenFloors().hasKey(floor.id)));
            addAreaRows(rows, haState, EntitySorter.sortAreas(haState.getAreasInFloor(floor.id)), floor.name);
        }

        addAreaRows(rows, haState, EntitySorter.sortAreas(haState.getUnflooredAreas()), null);

        return rows;
    }

    function addAreaRows(rows as Array<VisibilityToggleRowModel>, haState as HaState,
                         areas as Array<AreaModel>, floorName as String or Null) as Void {
        for (var index = 0; index < areas.size(); index++) {
            var area = areas[index];
            rows.add(new VisibilityToggleRowModel(area.id, area.name, floorName, false,
                !haState.getHiddenAreas().hasKey(area.id)));
        }
    }
}
