import Toybox.Lang;
import Toybox.WatchUi;

// ToggleMenuItem flips its own checkbox before onSelect, and here the flip stands
// as the user's intent (unlike the entity menu's deferred click): checked means
// visible, so hidden is its negation.
class VisibilityToggleDelegate extends WatchUi.Menu2InputDelegate {
    private var _setHidden as Method(id as String, isHidden as Boolean) as Void;

    function initialize(setHidden as Method(id as String, isHidden as Boolean) as Void) {
        Menu2InputDelegate.initialize();
        _setHidden = setHidden;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item instanceof WatchUi.ToggleMenuItem) {
            _setHidden.invoke(item.getId() as String, !item.isEnabled());
        }
    }
}
