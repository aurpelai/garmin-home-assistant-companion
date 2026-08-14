import Toybox.Lang;
import Toybox.WatchUi;

class FloorEntityMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as FloorEntityMenu;
    private var _coordinator as Coordinator;

    function initialize(menu as FloorEntityMenu, coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var floorId = _menu.serviceTargetOf(item.getId());
        if (floorId != null) {
            _coordinator.toggleFloorLights(floorId as String);
        }
    }
}
