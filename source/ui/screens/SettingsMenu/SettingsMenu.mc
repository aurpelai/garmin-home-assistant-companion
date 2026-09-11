import Toybox.Lang;
import Toybox.WatchUi;

// Until structure has loaded there is no tree to show, so the filter row says
// so and the coordinator refuses to drill.
class SettingsMenu extends WatchUi.Menu2 {
    static const FILTER_ROW_ID = "settings-filter";

    function initialize(haState as HaState) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String });

        var subLabel = haState.hasAreas() ? null : WatchUi.loadResource(Rez.Strings.SettingsNotLoaded) as String;
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsFilter) as String, subLabel, FILTER_ROW_ID, null));
    }
}
