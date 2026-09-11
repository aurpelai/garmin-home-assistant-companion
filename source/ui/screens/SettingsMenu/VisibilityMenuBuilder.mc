import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState. Unlike the
// card loop it lists everything, hidden included, because hiding is only undone
// from here.
module VisibilityMenuBuilder {

    function buildFloorToggleRows(haState as HaState) as Array<VisibilityToggleRowModel> {
        var floors = haState.getFloors();
        var rows = [] as Array<VisibilityToggleRowModel>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            rows.add(new VisibilityToggleRowModel(floor.id, floor.name, !haState.getHiddenFloors().hasKey(floor.id)));
        }

        return rows;
    }

    function buildAreaToggleRows(haState as HaState, areas as Array<AreaModel>) as Array<VisibilityToggleRowModel> {
        var rows = [] as Array<VisibilityToggleRowModel>;

        for (var index = 0; index < areas.size(); index++) {
            var area = areas[index];
            rows.add(new VisibilityToggleRowModel(area.id, area.name, !haState.getHiddenAreas().hasKey(area.id)));
        }

        return rows;
    }

    // One drill row per floor, then "Other" for the unfloored areas when any exist.
    // A row whose areas are all absent from the loop says why — the floor is
    // hidden, or every area under it is — while staying editable.
    function buildAreaVisibilityRows(haState as HaState, otherTitle as String) as Array<AreaVisibilityRowModel> {
        var floors = haState.getFloors();
        var rows = [] as Array<AreaVisibilityRowModel>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            rows.add(new AreaVisibilityRowModel(floor.id, floor.name, resolveFloorSubLabelId(haState, floor.id)));
        }

        if (haState.getUnflooredAreas().size() > 0) {
            rows.add(new AreaVisibilityRowModel(AreaVisibilityMenu.OTHER_ROW_ID, otherTitle,
                resolveAllHiddenSubLabelId(haState.getVisibleUnflooredAreas())));
        }

        return rows;
    }

    function resolveFloorSubLabelId(haState as HaState, floorId as String) as ResourceId or Null {
        if (haState.getHiddenFloors().hasKey(floorId)) {
            return Rez.Strings.SettingsFloorHidden;
        }

        if (haState.getAreasInFloor(floorId).size() == 0) {
            return null;
        }

        return resolveAllHiddenSubLabelId(haState.getVisibleAreasInFloor(floorId));
    }

    function resolveAllHiddenSubLabelId(visibleAreas as Array<AreaModel>) as ResourceId or Null {
        return visibleAreas.size() == 0 ? Rez.Strings.SettingsAllAreasHidden : null;
    }
}
