import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FloorEntityMenu extends WatchUi.Menu2 {
    public var floorId as String;

    private var _session as HomeSession;

    function initialize(session as HomeSession, floorId as String, floorName as String) {
        Menu2.initialize({ :title => floorName });
        self.floorId = floorId;
        _session = session;

        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.AllLights) as String, null,
            :allLights, session.areFloorLightsOn(floorId), null));
    }

    function onShow() as Void {
        (Application.getApp() as HaCompanionApp).setCurrentView(self);
        _session.refreshState(method(:draw));
    }

    function draw() as Void {
        var index = findItemById(:allLights);
        if (index < 0) {
            return;
        }

        (getItem(index) as WatchUi.ToggleMenuItem).setEnabled(_session.areFloorLightsOn(floorId));
        WatchUi.requestUpdate();
    }
}
