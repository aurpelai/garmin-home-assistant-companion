import Toybox.Lang;
import Toybox.WatchUi;

class VisibilityFilterMenu extends WatchUi.Menu2 {
    static const FLOORS_ROW_ID = "filter-floors";
    static const AREAS_ROW_ID = "filter-areas";

    function initialize(haState as HaState) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsFilter) as String });

        if (haState.getFloors().size() > 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.SettingsFloors) as String, null, FLOORS_ROW_ID, null));
        }

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsAreas) as String, null, AREAS_ROW_ID, null));
    }
}
