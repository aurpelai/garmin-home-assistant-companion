import Toybox.Lang;

// The row id for the floor's whole-lights row. Not an entity id: the row's
// identity and its service target diverge here, the target being the floor.
const FLOOR_LIGHTS_ROW_ID = "floor.lights";

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
// Groups and unavailable lights are excluded because Home Assistant expands the
// floor itself and the call cannot reach a dead light — the same scope the
// override covers, so the row's state and its pending status describe exactly
// what a tap would command.
function buildFloorLightRows(haState as HaState, floorId as String) as Array<LightRowModel> {
    var lightIds = haState.getLightIdsInFloor(floorId);
    var commandableCount = 0;
    var isOn = false;
    var isPending = false;

    for (var index = 0; index < lightIds.size(); index++) {
        var entityId = lightIds[index];
        var light = haState.getLight(entityId) as LightModel;
        if (light.memberIds != null || !light.available) {
            continue;
        }

        commandableCount++;
        isOn = isOn || haState.isOn(entityId);
        isPending = isPending || haState.isPending(entityId);
    }

    if (commandableCount == 0) {
        return [] as Array<LightRowModel>;
    }

    return [new LightRowModel(FLOOR_LIGHTS_ROW_ID, floorId, null, isOn, true, null, isPending)]
        as Array<LightRowModel>;
}
