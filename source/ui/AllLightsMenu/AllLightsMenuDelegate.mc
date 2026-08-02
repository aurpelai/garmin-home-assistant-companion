import Toybox.Lang;
import Toybox.WatchUi;

class AllLightsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as AllLightsMenu;
    private var _session as HomeSession;

    function initialize(menu as AllLightsMenu, session as HomeSession) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _session = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var toggle = item as WatchUi.ToggleMenuItem;

        _session.toggleFloorLights(_menu.floorId,
            new FloorToggleHandler(_menu, toggle, _session).method(:onComplete));
    }
}
