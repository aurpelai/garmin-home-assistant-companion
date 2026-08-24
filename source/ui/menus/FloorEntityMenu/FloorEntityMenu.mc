import Toybox.Lang;
import Toybox.WatchUi;

// The row is built once and frozen for the life of the menu: a rebuild updates
// its toggle state and nothing else, so nothing moves or vanishes under the
// user's finger while the menu is open.
class FloorEntityMenu extends WatchUi.Menu2 {
    private var _coordinator as Coordinator;
    private var _floorId as String;

    function initialize(coordinator as Coordinator, floorId as String, model as FloorEntityMenuModel) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _floorId = floorId;

        for (var index = 0; index < model.lights.size(); index++) {
            var row = model.lights[index];
            addItem(new WatchUi.ToggleMenuItem(
                WatchUi.loadResource(Rez.Strings.AllLights) as String, null,
                row.rowId, row.isOn, null));
        }

        setModel(model);
    }

    function onShow() as Void {
        _coordinator.onViewShown(self);
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
    }

    function isObsolete(haState as HaState) as Boolean {
        return haState.getFloor(_floorId) == null;
    }

    function rebuild(haState as HaState) as Void {
        var model = FloorEntityMenuBuilder.build(haState, _floorId);
        if (model != null) {
            setModel(model);
        }
    }

    function setModel(model as FloorEntityMenuModel) as Void {
        setTitle(model.title);

        for (var index = 0; index < model.lights.size(); index++) {
            var row = model.lights[index];
            var item = findItem(row.rowId);

            if (item != null) {
                (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
            }
        }
    }

    function toServiceTarget(rowId as Object or Null) as String or Null {
        return FloorEntityMenuModel.LIGHTS_ROW_ID.equals(rowId) ? _floorId : null;
    }

    private function findItem(rowId as String) as WatchUi.MenuItem or Null {
        var index = findItemById(rowId);
        return index < 0 ? null : getItem(index);
    }
}
