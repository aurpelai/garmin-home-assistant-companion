import Toybox.Lang;
import Toybox.WatchUi;

// ToggleMenuItem flips its own checkbox before onSelect, and here the flip stands
// as the user's intent (unlike the entity menu's deferred click): checked means
// visible, so hidden is its negation.
class VisibilityToggleDelegate extends WatchUi.Menu2InputDelegate {
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
        var isHidden = !item.isEnabled();

        if (row instanceof FloorVisibilityRowModel) {
            _coordinator.setFloorHidden(row.id, isHidden);
        } else {
            _coordinator.setAreaHidden(row.id, isHidden);
        }
    }
}
