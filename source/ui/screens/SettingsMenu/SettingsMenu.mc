import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {
    static const VISIBILITY_ROW_ID = "settings-visibility";
    static const INCLUDE_LABELS_ROW_ID = "settings-include-labels";

    function initialize(haState as HaState) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String });

        var notLoaded = WatchUi.loadResource(Rez.Strings.SettingsNotLoaded) as String;
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsVisibility) as String,
            haState.hasAreas() ? null : notLoaded, VISIBILITY_ROW_ID, null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsIncludeLabels) as String,
            haState.hasLabels() ? null : notLoaded, INCLUDE_LABELS_ROW_ID, null));
    }
}
