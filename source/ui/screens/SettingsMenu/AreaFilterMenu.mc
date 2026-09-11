import Toybox.Lang;
import Toybox.WatchUi;

// One drill row per floor, then "Other" for the unfloored areas. A row whose
// areas are all absent from the loop says why — the floor is hidden, or every
// area under it is — while staying editable, since hiding is only undone here.
class AreaFilterMenu extends WatchUi.Menu2 {
    // UNVERIFIED: a hyphen cannot occur in a Home Assistant object id, so this
    // sentinel can never collide with a real floor id.
    static const OTHER_ROW_ID = "other-areas";

    function initialize(haState as HaState) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsAreas) as String });

        var floors = haState.getFloors();

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            addItem(new WatchUi.MenuItem(floor.name, resolveFloorSubLabel(haState, floor.id), floor.id, null));
        }

        if (haState.getUnflooredAreas().size() > 0) {
            var subLabel = haState.getVisibleUnflooredAreas().size() > 0
                ? null
                : WatchUi.loadResource(Rez.Strings.SettingsAllAreasHidden) as String;
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.SettingsOtherAreas) as String, subLabel, OTHER_ROW_ID, null));
        }
    }

    private function resolveFloorSubLabel(haState as HaState, floorId as String) as String or Null {
        if (haState.getHiddenFloors().hasKey(floorId)) {
            return WatchUi.loadResource(Rez.Strings.SettingsFloorHidden) as String;
        }

        if (!haState.isFloorVisible(floorId)) {
            return WatchUi.loadResource(Rez.Strings.SettingsAllAreasHidden) as String;
        }

        return null;
    }
}
