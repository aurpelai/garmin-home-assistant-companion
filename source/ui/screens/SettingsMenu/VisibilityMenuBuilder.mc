import Toybox.Lang;

// Pure: turns floors or areas plus the hidden sets into toggle rows. Unlike the
// card loop it lists everything, hidden included, because hiding is only undone
// from here.
module VisibilityMenuBuilder {

    function buildFloorRows(haState as HaState) as Array<VisibilityRowModel> {
        var floors = haState.getFloors();
        var rows = [] as Array<VisibilityRowModel>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            rows.add(new VisibilityRowModel(floor.id, floor.name, !haState.getHiddenFloors().hasKey(floor.id)));
        }

        return rows;
    }

    function buildAreaRows(haState as HaState, areas as Array<AreaModel>) as Array<VisibilityRowModel> {
        var rows = [] as Array<VisibilityRowModel>;

        for (var index = 0; index < areas.size(); index++) {
            var area = areas[index];
            rows.add(new VisibilityRowModel(area.id, area.name, !haState.getHiddenAreas().hasKey(area.id)));
        }

        return rows;
    }
}
