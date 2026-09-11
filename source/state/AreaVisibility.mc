import Toybox.Lang;

// Every visibility fact derives from one question — which of a floor's areas are
// visible: an area is visible iff it is in its floor's visible set, and a floor
// is visible iff that set is non-empty. Hidden floors and hidden areas are two
// independent sets; hiding a floor suppresses its areas without touching their
// own membership, so un-hiding the floor brings back exactly what it had.
module AreaVisibility {

    function visibleAreasOfFloor(floor as FloorModel, hiddenFloors as Dictionary<String, Boolean>,
                                 hiddenAreas as Dictionary<String, Boolean>) as Array<String> {
        if (hiddenFloors.hasKey(floor.id)) {
            return [] as Array<String>;
        }

        var visible = [] as Array<String>;

        for (var index = 0; index < floor.areas.size(); index++) {
            var areaId = floor.areas[index];
            if (!hiddenAreas.hasKey(areaId)) {
                visible.add(areaId);
            }
        }

        return visible;
    }

    function isFloorVisible(floor as FloorModel, hiddenFloors as Dictionary<String, Boolean>,
                            hiddenAreas as Dictionary<String, Boolean>) as Boolean {
        return visibleAreasOfFloor(floor, hiddenFloors, hiddenAreas).size() > 0;
    }
}
