import Toybox.Application;
import Toybox.Lang;

// The hidden floor/area sets the user chose, persisted so the filter survives
// restarts and is readable from every process — storage is the only channel the
// background service shares with the app. Hidden ids are stored, not visible
// ones, so a floor or area newly appearing in Home Assistant defaults to visible.
(:background)
module VisibilityStore {
    const HIDDEN_FLOORS_KEY = "hiddenFloors";
    const HIDDEN_AREAS_KEY = "hiddenAreas";
    const VISIBLE_AREAS_KEY = "visibleAreas";

    function getHiddenFloors() as Dictionary<String, Boolean> {
        return readSet(HIDDEN_FLOORS_KEY);
    }

    function getHiddenAreas() as Dictionary<String, Boolean> {
        return readSet(HIDDEN_AREAS_KEY);
    }

    // The visible area ids resolved by the foreground against the current
    // structure, cached for the render requests of every process. Null until the
    // first structure has been fetched, and kept distinct from an empty list
    // (everything hidden) so a render before then stays unfiltered.
    function getVisibleAreaIds() as Array<String> or Null {
        var stored = Application.Storage.getValue(VISIBLE_AREAS_KEY);
        return stored instanceof Array ? stored as Array<String> : null;
    }

    function setHiddenFloors(hiddenFloors as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(HIDDEN_FLOORS_KEY, hiddenFloors as Application.Storage.ValueType);
    }

    function setHiddenAreas(hiddenAreas as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(HIDDEN_AREAS_KEY, hiddenAreas as Application.Storage.ValueType);
    }

    function setVisibleAreaIds(visibleAreaIds as Array<String>) as Void {
        Application.Storage.setValue(VISIBLE_AREAS_KEY, visibleAreaIds as Application.Storage.ValueType);
    }

    function readSet(key as String) as Dictionary<String, Boolean> {
        var stored = Application.Storage.getValue(key);
        return stored instanceof Dictionary ? stored as Dictionary<String, Boolean> : {} as Dictionary<String, Boolean>;
    }
}
