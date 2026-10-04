import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (SettingsMenu.VISIBILITY_ROW_ID.equals(item.getId())) {
            _coordinator.showVisibilityPicker();
        } else if (SettingsMenu.INCLUDE_LABELS_ROW_ID.equals(item.getId())) {
            _coordinator.showLabelPicker();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        _coordinator.onSettingsClosed();
    }
}
