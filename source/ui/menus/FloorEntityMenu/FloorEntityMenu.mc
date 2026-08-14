import Toybox.Lang;
import Toybox.WatchUi;

// The item set is added once here and never changes while the menu is visible,
// so a push can neither lose a row nor move the one under the user's finger.
class FloorEntityMenu extends WatchUi.Menu2 {
    private var _coordinator as Coordinator;
    private var _floorId as String;
    private var _model as FloorEntityMenuModel;

    function initialize(coordinator as Coordinator, floorId as String, model as FloorEntityMenuModel) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _floorId = floorId;
        _model = model;

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
            var itemIndex = findItemById(row.rowId);
            if (itemIndex >= 0) {
                (getItem(itemIndex) as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
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
}
