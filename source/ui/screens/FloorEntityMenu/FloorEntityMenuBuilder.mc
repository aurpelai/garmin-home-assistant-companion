import Toybox.Lang;

module FloorEntityMenuBuilder {

    function build(haState as HaState, floorId as String) as FloorEntityMenuModel or Null {
        var floor = haState.getFloor(floorId);

        if (floor == null) {
            return null;
        }

        return new FloorEntityMenuModel(floor.name, buildLightRows(haState, floorId));
    }

    function buildLightRows(haState as HaState, floorId as String) as Array<ToggleRowModel> {
        var lights = haState.resolveVisibleToggleablesInFloor(floorId, Domain.LIGHT);

        if (lights.size() == 0) {
            return [] as Array<ToggleRowModel>;
        }

        return [new ToggleRowModel(FloorEntityMenuModel.LIGHTS_ROW_ID, null,
            haState.hasAnyOn(lights), null)] as Array<ToggleRowModel>;
    }
}
