import Toybox.Lang;
import Toybox.WatchUi;

// Lights within an area (or the combined "All lights" list). Each row is a
// native toggle showing the light's friendly name and on/off state; selecting a
// row toggles it, and the switch flips itself optimistically.
class LightMenu extends WatchUi.Menu2 {

    function initialize(store as LightStore, title as String, lights as Array<String>) {
        Menu2.initialize({ :title => title });

        if (lights.size() == 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.NoLights) as String, null, :none, null));
            return;
        }
        for (var i = 0; i < lights.size(); i++) {
            addItem(makeItem(store, lights[i]));
        }
    }

    static function makeItem(store as LightStore, entityId as String) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(
            friendlyName(entityId), restingSubLabel(store, entityId),
            entityId, store.isOn(entityId), null);
    }

    // A row's sublabel when nothing is in flight. Empty today; #4 fills it with
    // the group's member count. This is the single seam #4 changes: the initial
    // render and the post-toggle restore both read the resting value from here,
    // so the toggle path needs no change when counts land.
    static function restingSubLabel(store as LightStore, entityId as String) as String or Null {
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
    private var _store as LightStore;

    function initialize(store as LightStore) {
        Menu2InputDelegate.initialize();
        _store = store;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof String)) { return; }  // e.g. the :none placeholder
        var entityId = id as String;
        var toggle = item as WatchUi.ToggleMenuItem;
        // Capture the resting sublabel now so it can be restored on settle,
        // rather than blindly cleared (#4 makes this a group's member count).
        var resting = LightMenu.restingSubLabel(_store, entityId);
        toggle.setSubLabel(WatchUi.loadResource(Rez.Strings.Toggling) as String);
        WatchUi.requestUpdate();
        _store.toggle(entityId,
            new ToggleSettler(toggle, _store, entityId, resting).method(:settle));
    }
}

// Corrects a single row after its toggle round-trips: snaps the native switch
// back to the store's state (a no-op on success, a flip-back on failure) and
// restores the resting sublabel that the in-flight "Toggling" note replaced.
class ToggleSettler {
    private var _item as WatchUi.ToggleMenuItem;
    private var _store as LightStore;
    private var _entityId as String;
    private var _restingSubLabel as String or Null;

    function initialize(
            item as WatchUi.ToggleMenuItem, store as LightStore, entityId as String,
            restingSubLabel as String or Null) {
        _item = item;
        _store = store;
        _entityId = entityId;
        _restingSubLabel = restingSubLabel;
    }

    function settle() as Void {
        _item.setEnabled(_store.isOn(_entityId));
        _item.setSubLabel(_restingSubLabel);
        WatchUi.requestUpdate();
    }
}
