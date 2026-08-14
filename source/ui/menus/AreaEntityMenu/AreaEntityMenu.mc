import Toybox.Lang;
import Toybox.WatchUi;

// A push only ever appends, so every row already on screen keeps its position
// and the one under the user's finger cannot move or vanish. Rows arrive late
// routinely: a refresh fetches lights and sensors as separate requests, so a
// menu opened between the two starts without the domain still in flight.
class AreaEntityMenu extends WatchUi.Menu2 {
    private var _coordinator as Coordinator;
    private var _areaId as String;

    function initialize(coordinator as Coordinator, areaId as String, model as AreaEntityMenuModel) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _areaId = areaId;
        setModel(model);
    }

    function onShow() as Void {
        _coordinator.onViewShown(self);
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
    }

    function rebuild(haState as HaState) as Boolean {
        var model = buildAreaEntityMenuModel(haState, _areaId);
        if (model == null) {
            return false;
        }

        setModel(model);
        return true;
    }

    function setModel(model as AreaEntityMenuModel) as Void {
        setTitle(model.title);

        for (var index = 0; index < model.lights.size(); index++) {
            var row = model.lights[index];
            var item = findItem(row.rowId);

            if (item == null) {
                addItem(new WatchUi.ToggleMenuItem(
                    labelOf(row.name, row.rowId), lightSubLabel(row), row.rowId, row.isOn, null));
            } else {
                (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
                item.setSubLabel(lightSubLabel(row));
            }
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            var item = findItem(row.rowId);

            if (item == null) {
                addItem(new WatchUi.MenuItem(
                    labelOf(row.name, row.rowId), sensorSubLabel(row), row.rowId, null));
            } else {
                item.setSubLabel(sensorSubLabel(row));
            }
        }

        updateEmptyRow(model);
    }

    // The only row a push may remove, and it is safe to: it exists precisely
    // while there is nothing else to focus, so nothing can be focused on it
    // that the arriving rows do not replace.
    private function updateEmptyRow(model as AreaEntityMenuModel) as Void {
        var index = findItemById(EMPTY_ROW_ID);
        var isEmpty = model.lights.size() == 0 && model.sensors.size() == 0;

        if (isEmpty && index < 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.NoEntitiesInArea) as String, null, EMPTY_ROW_ID, null));
        } else if (!isEmpty && index >= 0) {
            deleteItem(index);
        }
    }

    private function findItem(rowId as String) as WatchUi.MenuItem or Null {
        var index = findItemById(rowId);
        return index < 0 ? null : getItem(index);
    }

    static const EMPTY_ROW_ID = :none;

    static function labelOf(name as String or Null, rowId as String) as String {
        return name == null || (name as String).length() == 0 ? rowId : name as String;
    }

    static function lightSubLabel(row as LightRowModel) as String or Null {
        var memberCount = row.memberCount;

        if (!row.isAvailable) {
            return WatchUi.loadResource(
                memberCount == null ? Rez.Strings.Unavailable : Rez.Strings.GroupUnavailable) as String;
        }

        if (memberCount == null) {
            return null;
        }

        if (memberCount == 1) {
            return WatchUi.loadResource(Rez.Strings.GroupLightCountOne) as String;
        }

        return Lang.format(WatchUi.loadResource(Rez.Strings.GroupLightCount) as String, [memberCount]);
    }

    static function sensorSubLabel(row as SensorRowModel) as String {
        var displayValue = row.displayValue;

        if (!row.isAvailable || displayValue == null) {
            return WatchUi.loadResource(Rez.Strings.Unavailable) as String;
        }

        return displayValue as String;
    }
}
