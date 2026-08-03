import Toybox.Lang;
import Toybox.WatchUi;

class AreaEntityMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as AreaEntityMenu;
    private var _session as HomeSession;

    function initialize(menu as AreaEntityMenu, session as HomeSession) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) {
            return;   // a reading or the no-entities row: inert, and no toggle to cast to
        }
        var toggle = item as WatchUi.ToggleMenuItem;
        var entityId = toggle.getId() as String;
        if (!_session.isAvailable(entityId)) {
            // Unavailable rows aren't toggleable: undo the native tap's flip and
            // fire no service call.
            toggle.setEnabled(!toggle.isEnabled());
            WatchUi.requestUpdate();
            return;
        }
        // The native ToggleMenuItem already flipped on tap; it stays flipped
        // with no in-flight affordance until server truth arrives.
        _session.toggleState(entityId,
            new ToggleHandler(_menu, toggle, _session, entityId).method(:onComplete));
    }
}
