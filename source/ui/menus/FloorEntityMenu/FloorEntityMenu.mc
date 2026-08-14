import Toybox.Lang;
import Toybox.WatchUi;

// A push only ever appends, so every row already on screen keeps its position
// and the one under the user's finger cannot move or vanish. The whole-lights
// row arrives late whenever the menu is opened before the lights request lands.
class FloorEntityMenu extends WatchUi.Menu2 {
    private var _coordinator as Coordinator;
    private var _floorId as String;
    private var _model as FloorEntityMenuModel;

    function initialize(coordinator as Coordinator, floorId as String, model as FloorEntityMenuModel) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _floorId = floorId;
        _model = model;
        setModel(model);
    }

    function onShow() as Void {
        _coordinator.onViewShown(self);
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
    }

    function rebuild(haState as HaState) as Boolean {
        var model = buildFloorEntityMenuModel(haState, _floorId);
        if (model == null) {
            return false;
        }

        setModel(model);
        return true;
    }

    function setModel(model as FloorEntityMenuModel) as Void {
        _model = model;
        setTitle(model.title);

        for (var index = 0; index < model.lights.size(); index++) {
            var row = model.lights[index];
            var item = findItem(row.rowId);

            if (item == null) {
                addItem(new WatchUi.ToggleMenuItem(
                    WatchUi.loadResource(Rez.Strings.AllLights) as String, null,
                    row.rowId, row.isOn, null));
            } else {
                (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
            }
        }
    }

    // A floor row's identity and its service target diverge, so the delegate
    // cannot read the target off the platform event and asks here instead.
    function serviceTargetOf(rowId as Object or Null) as String or Null {
        for (var index = 0; index < _model.lights.size(); index++) {
            var row = _model.lights[index];
            if (row.rowId.equals(rowId)) {
                return row.serviceTarget;
            }
        }

        return null;
    }

    private function findItem(rowId as String) as WatchUi.MenuItem or Null {
        var index = findItemById(rowId);
        return index < 0 ? null : getItem(index);
    }
}
