import Toybox.Lang;

// A floor's visibility derives from one question — which of its areas are
// visible: a floored area is visible iff it is in that set, and the floor iff the
// set is non-empty. Hidden floors and hidden areas are two independent sets;
// hiding a floor suppresses its areas without touching their own membership, so
// un-hiding the floor brings back exactly what it had. An unfloored area answers
// to the hidden-area set alone.
module AreaVisibility {

    function resolveVisibleAreaIds(floor as FloorModel, hiddenFloors as Dictionary<String, Boolean>,
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
        return resolveVisibleAreaIds(floor, hiddenFloors, hiddenAreas).size() > 0;
    }
}
