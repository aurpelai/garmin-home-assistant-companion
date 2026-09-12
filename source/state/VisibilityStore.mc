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

    // The unfloored areas hide as a group under this pseudo floor id. Registry ids
    // are slugified from the name with "_" as the separator, so a hyphen can never
    // occur in a real floor id and this collides with none.
    const UNFLOORED_FLOOR_ID = "unfloored-areas";

    function getHiddenFloors() as Dictionary<String, Boolean> {
        return readMembers(HIDDEN_FLOORS_KEY);
    }

    function getHiddenAreas() as Dictionary<String, Boolean> {
        return readMembers(HIDDEN_AREAS_KEY);
    }

    function setHiddenFloors(hiddenFloors as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(HIDDEN_FLOORS_KEY, hiddenFloors as Application.Storage.ValueType);
    }

    function setHiddenAreas(hiddenAreas as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(HIDDEN_AREAS_KEY, hiddenAreas as Application.Storage.ValueType);
    }

    function readMembers(key as String) as Dictionary<String, Boolean> {
        var stored = Application.Storage.getValue(key);
        return stored instanceof Dictionary ? stored as Dictionary<String, Boolean> : {} as Dictionary<String, Boolean>;
    }
}
