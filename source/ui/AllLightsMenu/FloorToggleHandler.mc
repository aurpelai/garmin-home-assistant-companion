import Toybox.Lang;
import Toybox.WatchUi;

// Once a floor toggle resolves, snaps the switch to the floor's derived on
// state — a no-op on success, a flip-back on failure — then refreshes state so
// the cards behind converge.
class FloorToggleHandler {
    private var _menu as AllLightsMenu;
    private var _item as WatchUi.ToggleMenuItem;
    private var _session as HomeSession;

    function initialize(menu as AllLightsMenu, item as WatchUi.ToggleMenuItem, session as HomeSession) {
        _menu = menu;
        _item = item;
        _session = session;
    }

    function onComplete() as Void {
        _item.setEnabled(_session.areFloorLightsOn(_menu.floorName));
        WatchUi.requestUpdate();

        _session.refreshState(method(:onRefreshed));
    }

    function onRefreshed() as Void {
        _item.setEnabled(_session.areFloorLightsOn(_menu.floorName));
        WatchUi.requestUpdate();
    }
}
