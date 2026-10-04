import Toybox.Lang;
import Toybox.WatchUi;

// ToggleMenuItem flips its own checkbox before onSelect, and here the flip stands
// as the user's intent (unlike the entity menu's deferred click).
class VisibilityPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) {
            return;
        }

        var row = item.getId() as VisibilityRowModel;

        if (row instanceof FloorVisibilityRowModel) {
            _coordinator.setFloorVisibility(row.id, item.isEnabled());
        } else {
            _coordinator.setAreaVisibility(row.id, item.isEnabled());
        }
    }
}
