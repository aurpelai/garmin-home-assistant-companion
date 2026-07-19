import Toybox.Lang;
import Toybox.WatchUi;

// Top-level menu: one row per area (that has lights), plus an "All lights" row.
// Each MenuItem's id carries the area name; the sentinel :allLights id opens the
// combined list.
class AreaMenu extends WatchUi.Menu2 {
    function initialize(store as LightStore) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.AppName) as String });

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.AllLights) as String, null, :allLights, null));

        var areas = store.map.areas;
        for (var i = 0; i < areas.size(); i++) {
            var name = areas[i].get(:name) as String;
            addItem(new WatchUi.MenuItem(name, null, name, null));
        }
    }
}

class AreaMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _store as LightStore;

    function initialize(store as LightStore) {
        Menu2InputDelegate.initialize();
        _store = store;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var title;
        var lights;
        if (id == :allLights) {
            title = WatchUi.loadResource(Rez.Strings.AllLights) as String;
            lights = _store.map.allLights();
        } else {
            title = id as String;
            lights = _store.map.lightsForArea(id as String);
        }
        WatchUi.pushView(new LightMenu(_store, title, lights),
            new LightMenuDelegate(_store), WatchUi.SLIDE_LEFT);
    }
}
