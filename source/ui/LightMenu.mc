import Toybox.Lang;
import Toybox.WatchUi;

// Lights within an area (or the combined "All lights" list). Each row is a
// native toggle showing the light's friendly name and on/off state; selecting a
// row toggles it, and the switch flips itself optimistically.
class LightMenu extends WatchUi.Menu2 {

    function initialize(session as LightSession, title as String, lights as Array<String>) {
        Menu2.initialize({ :title => title });

        if (lights.size() == 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.NoLights) as String, null, :none, null));
            return;
        }
        for (var i = 0; i < lights.size(); i++) {
            addItem(makeItem(session, lights[i]));
        }
    }

    static function makeItem(session as LightSession, entityId as String) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(
            friendlyName(entityId), idleSubLabel(session, entityId),
            entityId, session.isOn(entityId), null);
    }

    // TODO(#4): group member count. Null today; both render and restore route
    // through here so #4 changes only this body, not the toggle path.
    static function idleSubLabel(session as LightSession, entityId as String) as String or Null {
        return null;
    }

    // "light.kitchen_ceiling" -> "Kitchen Ceiling"
    static function friendlyName(entityId as String) as String {
        var s = entityId;
        var dot = s.find(".");
        // substring is typed String?; dot+1 is a valid in-range index here.
        if (dot != null) { s = s.substring(dot + 1, s.length()) as String; }
        var chars = s.toCharArray();
        var out = "";
        var capNext = true;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c == '_') {
                out += " ";
                capNext = true;
            } else {
                var piece = c.toString();
                out += capNext ? piece.toUpper() : piece;
                capNext = false;
            }
        }
        return out;
    }
}

class LightMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _session as LightSession;

    function initialize(session as LightSession) {
        Menu2InputDelegate.initialize();
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof String)) { return; }  // e.g. the :none placeholder
        var entityId = id as String;
        var toggle = item as WatchUi.ToggleMenuItem;
        // Capture the idle sublabel now so completion restores it rather than
        // blindly clearing it.
        var idle = LightMenu.idleSubLabel(_session, entityId);
        toggle.setSubLabel(WatchUi.loadResource(Rez.Strings.Toggling) as String);
        WatchUi.requestUpdate();
        _session.toggle(entityId,
            new ToggleHandler(toggle, _session, entityId, idle).method(:onComplete));
    }
}

// Corrects a single row once its toggle completes: snaps the native switch back
// to the session's state (a no-op on success, a flip-back on failure) and restores
// the idle sublabel that the in-flight "Toggling" note replaced.
class ToggleHandler {
    private var _item as WatchUi.ToggleMenuItem;
    private var _session as LightSession;
    private var _entityId as String;
    private var _idleSubLabel as String or Null;

    function initialize(
            item as WatchUi.ToggleMenuItem, session as LightSession, entityId as String,
            idleSubLabel as String or Null) {
        _item = item;
        _session = session;
        _entityId = entityId;
        _idleSubLabel = idleSubLabel;
    }

    function onComplete() as Void {
        _item.setEnabled(_session.isOn(_entityId));
        _item.setSubLabel(_idleSubLabel);
        WatchUi.requestUpdate();
    }
}
