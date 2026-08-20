import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState.
module FloorEntityMenuBuilder {

    function build(haState as HaState, floorId as String) as FloorEntityMenuModel or Null {
        var floor = haState.getFloor(floorId);

        if (floor == null) {
            return null;
        }

        return new FloorEntityMenuModel(floor.name, buildLightRows(haState, floorId));
    }

    // One row per domain present on the floor, so a floor with no lights gets no
    // row rather than a dead one.
    //
    // Read over the same scope the fan-out overrides, so the row's state and its
    // pending status describe exactly what a tap would command.
    function buildLightRows(haState as HaState, floorId as String) as Array<LightRowModel> {
        var lights = haState.getLightsInFloor(floorId);

        if (lights.size() == 0) {
            return [] as Array<LightRowModel>;
        }

        return [new LightRowModel(FloorEntityMenuModel.LIGHTS_ROW_ID, null,
            haState.hasAnyOn(lights), true, null)] as Array<LightRowModel>;
    }
}
