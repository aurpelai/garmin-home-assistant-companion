import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {
    static const VISIBILITY_ROW_ID = "settings-visibility";

    function initialize(haState as HaState) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String });

        var subLabel = haState.hasAreas() ? null : WatchUi.loadResource(Rez.Strings.SettingsNotLoaded) as String;
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsVisibility) as String, subLabel, VISIBILITY_ROW_ID, null));
    }
}
