import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Top-level menu: one row per area that has lights. Each MenuItem's id
// carries the area name.
class AreaMenu extends WatchUi.Menu2 {
    function initialize(session as HomeSession) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.AppName) as String });

        var areas = session.areas();
        for (var i = 0; i < areas.size(); i++) {
            var name = areas[i].get(:name) as String;
            addItem(new WatchUi.MenuItem(name, null, name, null));
        }
    }

    function onShow() as Void {
        (Application.getApp() as HaControllerApp).setCurrentView(self);
    }

    // The named redraw seam onActive dispatches to (see EntityMenu.redraw).
    // No-op here: the area menu shows no light state.
    function redraw() as Void {
    }
}

class AreaMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _session as HomeSession;

    function initialize(session as HomeSession) {
        Menu2InputDelegate.initialize();
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var area = item.getId() as String;
        var lights = _session.listLightsInArea(area);
        var menu = new EntityMenu(_session, area, lights);
        WatchUi.pushView(menu, new EntityMenuDelegate(menu, _session), WatchUi.SLIDE_LEFT);
    }
}
