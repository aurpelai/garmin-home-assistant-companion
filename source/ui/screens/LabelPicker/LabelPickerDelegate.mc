import Toybox.Lang;
import Toybox.WatchUi;

// ToggleMenuItem flips its own checkbox before onSelect, and here the flip stands
// as the user's intent: checked means watched.
class LabelPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _coordinator as Coordinator;

    function initialize(coordinator as Coordinator) {
        Menu2InputDelegate.initialize();
        _coordinator = coordinator;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) {
            return;
        }

        _coordinator.setLabelWatched(item.getId() as String, item.isEnabled());
    }
}
