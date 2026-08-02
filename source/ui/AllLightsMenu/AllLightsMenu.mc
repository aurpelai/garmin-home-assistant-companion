import Toybox.Lang;
import Toybox.WatchUi;

// The single "All Lights" control for a floor: one toggle row whose switch
// reflects whether any of the floor's lights are on, and whose selection turns
// the whole floor on or off at once (see AllLightsMenuDelegate).
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
