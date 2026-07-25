import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Top-level menu: one row per area (that has lights), plus an "All lights" row.
// Each MenuItem's id carries the area name; the sentinel :allLights id opens the
// combined list.
class AreaMenu extends WatchUi.Menu2 {
    function initialize(session as LightSession) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.AppName) as String });

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.AllLights) as String, null, :allLights, null));

        var areas = session.areas();
        for (var i = 0; i < areas.size(); i++) {
            var name = areas[i].get(:name) as String;
            addItem(new WatchUi.MenuItem(name, null, name, null));
        }
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
    }

    // The named redraw seam onActive dispatches to (see LightMenu.redraw).
    // No-op here: the area menu shows no light state.
    function redraw() as Void {
    }
}

class AreaMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _session as LightSession;

    function initialize(session as LightSession) {
        Menu2InputDelegate.initialize();
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var title;
        var lights;
        if (id == :allLights) {
            title = WatchUi.loadResource(Rez.Strings.AllLights) as String;
            lights = _session.listAllLights();
        } else {
            title = id as String;
            lights = _session.listLightsInArea(id as String);
        }
        var menu = new LightMenu(_session, title, lights);
        WatchUi.pushView(menu, new LightMenuDelegate(menu, _session), WatchUi.SLIDE_LEFT);
    }
}
