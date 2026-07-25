import Toybox.Lang;
import Toybox.WatchUi;

// Lights within an area (or the combined "All lights" list). Each row is a
// native toggle showing the light's friendly name and on/off state; selecting a
// row toggles it, and the switch flips itself optimistically.
//
// The menu renders from cached session state instantly. onShow fires a fresh
// snapshot fetch and, when it returns, silently converges the visible rows to
// server truth — so entering the view (navigation) and returning to it (resume)
// both self-heal without ever blocking on the network.
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
            addItem(makeItem(session, lights[i]));
        }
    }

    function onShow() as Void {
        _session.refresh(method(:refreshRows));
    }

    // Only the on/off markers move; the item list is never rebuilt.
    function refreshRows() as Void {
        for (var i = 0; i < _lights.size(); i++) {
            var entityId = _lights[i];
            var index = findItemById(entityId);
            if (index < 0) {
                continue;
            }
            var item = getItem(index) as WatchUi.ToggleMenuItem;
            item.setEnabled(_session.isOn(entityId));
        }
        WatchUi.requestUpdate();
    }

    static function makeItem(session as LightSession, entityId as String) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(
            session.getName(entityId), idleSubLabel(session, entityId),
            entityId, session.isOn(entityId), null);
    }

    // A group row's idle sublabel is its member count ("4 lights", "1 light"); a
    // plain light has none. Both initial render and post-toggle restore route
    // through here, so this is the single seam that decides the idle sublabel.
    static function idleSubLabel(session as LightSession, entityId as String) as String or Null {
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
        if (!(id instanceof String)) { return; }  // e.g. the :none placeholder
        var entityId = id as String;
        // The native ToggleMenuItem already flipped on tap; it stays flipped
        // with no in-flight affordance until server truth arrives.
        _session.toggle(entityId,
            new ToggleHandler(_menu, item as WatchUi.ToggleMenuItem, _session, entityId).method(:onComplete));
    }
}

// Once a toggle resolves, snaps the switch to the session's state — a no-op on
// success, a flip-back on failure — then reconciles every visible row.
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

        _session.refresh(_menu.method(:refreshRows));
    }
}
