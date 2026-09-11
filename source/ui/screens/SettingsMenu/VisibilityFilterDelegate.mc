import Toybox.Lang;
import Toybox.WatchUi;

class VisibilityFilterDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (VisibilityFilterMenu.FLOORS_ROW_ID.equals(id)) {
            _coordinator.showFloorVisibility();
        } else if (VisibilityFilterMenu.AREAS_ROW_ID.equals(id)) {
            _coordinator.showAreaVisibility();
        }
    }
}
