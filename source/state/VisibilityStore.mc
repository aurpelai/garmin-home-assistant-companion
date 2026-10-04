import Toybox.Application;
import Toybox.Lang;

(:background)
module VisibilityStore {
    const HIDDEN_FLOORS_KEY = "hiddenFloors";
    const HIDDEN_AREAS_KEY = "hiddenAreas";
    const INCLUDED_LABELS_KEY = "includedLabels";

    // The floorless areas hide as a group under this pseudo floor id. Registry ids
    // are slugified from the name with "_" as the separator, so a hyphen can never
    // occur in a real floor id and this collides with none (verified from the Home
    // Assistant core source on 2026-09-12).
    const FLOORLESS_FLOOR_ID = "floorless-areas";

    function getHiddenFloors() as Dictionary<String, Boolean> {
        return getMembers(HIDDEN_FLOORS_KEY);
    }

    function getHiddenAreas() as Dictionary<String, Boolean> {
        return getMembers(HIDDEN_AREAS_KEY);
    }

    function getIncludedLabels() as Dictionary<String, Boolean> {
        return getMembers(INCLUDED_LABELS_KEY);
    }

    function getMembers(key as String) as Dictionary<String, Boolean> {
        var stored = Application.Storage.getValue(key);
        return stored instanceof Dictionary ? stored as Dictionary<String, Boolean> : {} as Dictionary<String, Boolean>;
    }

    function setHiddenFloors(hiddenFloors as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(HIDDEN_FLOORS_KEY, hiddenFloors as Application.Storage.ValueType);
    }

    function setHiddenAreas(hiddenAreas as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(HIDDEN_AREAS_KEY, hiddenAreas as Application.Storage.ValueType);
    }

    function setIncludedLabels(includedLabels as Dictionary<String, Boolean>) as Void {
        Application.Storage.setValue(INCLUDED_LABELS_KEY, includedLabels as Application.Storage.ValueType);
    }
}
