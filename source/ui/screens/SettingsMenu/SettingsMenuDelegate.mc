import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as SettingsMenu;
    private var _coordinator as Coordinator;

    function initialize(menu as SettingsMenu, coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (SettingsMenu.FILTER_ROW_ID.equals(item.getId()) && _menu.isFilterReady()) {
            _coordinator.showVisibilityFilter();
        }
    }
}
