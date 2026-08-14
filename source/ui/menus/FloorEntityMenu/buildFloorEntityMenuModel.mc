import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState.
//
// Takes the floor id and looks the floor up, so absence is discovered and
// answered here. Returns null when the floor is gone.
function buildFloorEntityMenuModel(haState as HaState, floorId as String) as FloorEntityMenuModel or Null {
    var floors = haState.getFloors();

    for (var index = 0; index < floors.size(); index++) {
        var floor = floors[index];
        if (floor.id.equals(floorId)) {
            return new FloorEntityMenuModel(
                floor.name == null ? floorId : floor.name as String,
                buildFloorLightRows(haState, floorId));
        }
    }

    return null;
}

// One row per domain present on the floor, so a floor with nothing commandable
// gets no row rather than a dead one.
//
// Read over the same scope the fan-out overrides, so the row's state and its
// pending status describe exactly what a tap would command.
function buildFloorLightRows(haState as HaState, floorId as String) as Array<LightRowModel> {
    var lightIds = haState.commandableFloorLightIds(floorId);

    if (lightIds.size() == 0) {
        return [] as Array<LightRowModel>;
    }

    var isOn = false;
    var isPending = false;

    for (var index = 0; index < lightIds.size(); index++) {
        isOn = isOn || haState.isOn(lightIds[index]);
        isPending = isPending || haState.isPending(lightIds[index]);
    }

    return [new LightRowModel(FloorEntityMenuModel.LIGHTS_ROW_ID, floorId, null, isOn, true,
        null, isPending)] as Array<LightRowModel>;
}
