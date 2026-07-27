import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Lights within an area. Each row is a native toggle showing the light's
// friendly name and on/off state; selecting a row toggles it, and the switch
// flips itself optimistically.
//
// The menu renders from cached session state instantly. onShow is the
// navigation trigger: it fires a fresh state fetch and, when it returns,
// silently converges the visible rows to server truth without ever blocking on
// the network. Resume is handled separately by the app's onActive; onShow may
// also fire on resume, a tolerated harmless double-fetch.
class LightMenu extends WatchUi.Menu2 {
    private var _session as LightSession;
    private var _lights as Array<String>;

    function initialize(session as LightSession, title as String, lights as Array<String>) {
        Menu2.initialize({ :title => title });
        _session = session;
        _lights = lights;

        if (lights.size() == 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.NoLights) as String, null, :none, null));
            return;
        }
        for (var i = 0; i < lights.size(); i++) {
            addItem(buildItem(session, lights[i]));
        }
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
        _session.refreshState(method(:redraw));
    }

    // The named redraw seam onActive dispatches to (see AreaMenu.redraw); any
    // new state-showing view implements it. Only the on/off markers move; the
    // item list is never rebuilt, so scroll and focus survive.
    function redraw() as Void {
        for (var i = 0; i < _lights.size(); i++) {
            var entityId = _lights[i];
            var index = findItemById(entityId);
            if (index < 0) {
                continue;
            }
            var item = getItem(index) as WatchUi.ToggleMenuItem;
            item.setEnabled(_session.isOn(entityId));
            item.setSubLabel(buildSubLabel(_session, entityId));
        }
        WatchUi.requestUpdate();
    }

    static function buildItem(session as LightSession, entityId as String) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(
            session.getName(entityId), buildSubLabel(session, entityId),
            entityId, session.isOn(entityId), null);
    }

    // The single seam for a row's sublabel: both construction and redraw route
    // through here, so the two never disagree on what a row shows.
    static function buildSubLabel(session as LightSession, entityId as String) as String or Null {
        if (!session.isAvailable(entityId)) {
            var stringId = session.isGroup(entityId) ? Rez.Strings.GroupUnavailable : Rez.Strings.Unavailable;
            return WatchUi.loadResource(stringId) as String;
        }
        if (!session.isGroup(entityId)) {
            return null;
        }
        var count = session.getMemberCount(entityId);
        return count + (count == 1 ? " light" : " lights");
    }
}

class LightMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as LightMenu;
    private var _session as LightSession;

    function initialize(menu as LightMenu, session as LightSession) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof String)) {
            return;   // e.g. the :none placeholder
        }
        var entityId = id as String;
        var toggle = item as WatchUi.ToggleMenuItem;
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

// Once a toggle resolves, snaps the switch to the session's state — a no-op on
// success, a flip-back on failure — then refreshes every visible row.
class ToggleHandler {
    private var _menu as LightMenu;
    private var _item as WatchUi.ToggleMenuItem;
    private var _session as LightSession;
    private var _entityId as String;

    function initialize(
            menu as LightMenu, item as WatchUi.ToggleMenuItem, session as LightSession,
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
