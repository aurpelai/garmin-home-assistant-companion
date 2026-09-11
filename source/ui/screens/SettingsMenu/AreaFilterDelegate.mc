import Toybox.Lang;
import Toybox.WatchUi;

class AreaFilterDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;

        if (AreaFilterMenu.OTHER_ROW_ID.equals(id)) {
            _coordinator.showUnflooredAreaVisibility();
        } else {
            _coordinator.showFloorAreaVisibility(id);
        }
    }
}
