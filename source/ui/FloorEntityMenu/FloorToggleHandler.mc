import Toybox.Lang;
import Toybox.WatchUi;

// Once a floor toggle resolves, snaps the switch to the floor's derived on
// state — a no-op on success, a flip-back on failure.
class FloorToggleHandler {
    private var _menu as FloorEntityMenu;
    private var _item as WatchUi.ToggleMenuItem;
    private var _session as HomeSession;

    function initialize(menu as FloorEntityMenu, item as WatchUi.ToggleMenuItem, session as HomeSession) {
        _menu = menu;
        _item = item;
        _session = session;
    }

    function onComplete() as Void {
        _item.setEnabled(_session.areFloorLightsOn(_menu.floorId));
        WatchUi.requestUpdate();

        _session.refreshState(method(:onRefreshed));
    }

    function onRefreshed() as Void {
        _item.setEnabled(_session.areFloorLightsOn(_menu.floorId));
        WatchUi.requestUpdate();
    }
}
