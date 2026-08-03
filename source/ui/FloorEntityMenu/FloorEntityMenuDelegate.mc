import Toybox.Lang;
import Toybox.WatchUi;

class FloorEntityMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as FloorEntityMenu;
    private var _session as HomeSession;

    function initialize(menu as FloorEntityMenu, session as HomeSession) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        _session.toggleFloorLights(_menu.floorId, method(:onToggleComplete));
    }

    // Holds no per-tap state, so overlapping taps cannot cross their snaps.
    function onToggleComplete() as Void {
        _menu.redraw();
        _session.refreshState(_menu.method(:redraw));
    }
}
