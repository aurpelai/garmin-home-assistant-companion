import Toybox.Lang;
import Toybox.WatchUi;

// The item set is built once here and frozen for the life of the menu: a push
// updates toggle states and nothing else. A floor gaining or losing its lights
// while the menu is open therefore changes no row, and seeing a changed set
// means reopening the menu.
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

    function rebuild(haState as HaState) as Boolean {
        var model = FloorEntityMenuBuilder.build(haState, _floorId);
        if (model == null) {
            return false;
        }

        setModel(model);
        return true;
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

    // A floor row's identity and its service target diverge, so the delegate
    // cannot read the target off the platform event and asks here instead.
    function toServiceTarget(rowId as Object or Null) as String or Null {
        return FloorEntityMenuModel.LIGHTS_ROW_ID.equals(rowId) ? _floorId : null;
    }

    private function findItem(rowId as String) as WatchUi.MenuItem or Null {
        var index = findItemById(rowId);
        return index < 0 ? null : getItem(index);
    }
}
