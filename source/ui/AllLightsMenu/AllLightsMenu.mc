import Toybox.Lang;
import Toybox.WatchUi;

class AllLightsMenu extends WatchUi.Menu2 {
    public var floorId as String;

    function initialize(session as HomeSession, floorId as String, floorName as String) {
        Menu2.initialize({ :title => floorName });
        self.floorId = floorId;

        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.AllLights) as String, null,
            :allLights, session.areFloorLightsOn(floorId), null));
    }
}
