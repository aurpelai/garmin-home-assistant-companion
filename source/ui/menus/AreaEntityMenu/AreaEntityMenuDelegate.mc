import Toybox.Lang;
import Toybox.WatchUi;

class AreaEntityMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    // A sensor row and the no-entities row are plain items, which is what makes
    // them inert: there is no toggle to read a target from.
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) {
            return;
        }

        _coordinator.toggleEntity(item.getId() as String);
    }
}
