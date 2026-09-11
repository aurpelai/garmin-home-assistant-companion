import Toybox.Lang;
import Toybox.WatchUi;

// The filter row self-gates: until structure has loaded there is no tree to show,
// so it carries a "not loaded yet" sub-label and does not drill.
class SettingsMenu extends WatchUi.Menu2 {
    static const FILTER_ROW_ID = "settings-filter";

    private var _filterReady as Boolean;

    function initialize(haState as HaState) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String });
        _filterReady = haState.hasAreas();

        var subLabel = _filterReady ? null : WatchUi.loadResource(Rez.Strings.SettingsNotLoaded) as String;
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsFilter) as String, subLabel, FILTER_ROW_ID, null));
    }

    function isFilterReady() as Boolean {
        return _filterReady;
    }
}
