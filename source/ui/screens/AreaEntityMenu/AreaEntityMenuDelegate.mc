import Toybox.Lang;
import Toybox.WatchUi;

class AreaEntityMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) {
            return;
        }

        var entityId = item.getId() as String;

        // ToggleMenuItem flips its own checkbox before this runs; undo it, because
        // the click is deferred and may turn out to be a double-click that toggles
        // nothing.
        (item as WatchUi.ToggleMenuItem).setEnabled(_coordinator.isOn(entityId));
        _coordinator.onEntityClick(entityId);
    }
}
