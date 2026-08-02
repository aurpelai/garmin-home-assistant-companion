import Toybox.Lang;
import Toybox.WatchUi;

// Once a toggle resolves, snaps the switch to the session's state — a no-op on
// success, a flip-back on failure — then refreshes every visible row.
class ToggleHandler {
    private var _menu as EntityMenu;
    private var _item as WatchUi.ToggleMenuItem;
    private var _session as HomeSession;
    private var _entityId as String;

    function initialize(
            menu as EntityMenu, item as WatchUi.ToggleMenuItem, session as HomeSession,
            entityId as String) {
        _menu = menu;
        _item = item;
        _session = session;
        _entityId = entityId;
    }

    function onComplete() as Void {
        _item.setEnabled(_session.isOn(_entityId));
        WatchUi.requestUpdate();

        _session.refreshState(_menu.method(:redraw));
    }
}
