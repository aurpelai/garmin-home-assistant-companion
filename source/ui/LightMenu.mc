import Toybox.Lang;
import Toybox.WatchUi;

// Lights within an area (or the combined "All lights" list). Each row shows the
// light's friendly name and an on/off icon; selecting a row toggles it and
// flips the icon optimistically.
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

    static function makeItem(store as LightStore, entityId as String) as WatchUi.IconMenuItem {
        var icon = new WatchUi.Bitmap({
            :rez => store.isOn(entityId) ? Rez.Drawables.IconOn : Rez.Drawables.IconOff });
        return new WatchUi.IconMenuItem(friendlyName(entityId), null, entityId, icon, null);
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
        _store.toggle(entityId, new IconUpdater(item as WatchUi.IconMenuItem, _store, entityId).method(:refresh));
    }
}

// Updates a single row's icon to reflect the (possibly reverted) state after a
// toggle round-trips.
class IconUpdater {
    private var _item as WatchUi.IconMenuItem;
    private var _store as LightStore;
    private var _entityId as String;

    function initialize(item as WatchUi.IconMenuItem, store as LightStore, entityId as String) {
        _item = item;
        _store = store;
        _entityId = entityId;
    }

    function refresh() as Void {
        _item.setIcon(new WatchUi.Bitmap({
            :rez => _store.isOn(_entityId) ? Rez.Drawables.IconOn : Rez.Drawables.IconOff }));
        WatchUi.requestUpdate();
    }
}
