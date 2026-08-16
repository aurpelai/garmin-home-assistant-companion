import Toybox.Lang;
import Toybox.WatchUi;

// The item set is built once here and frozen for the life of the menu: a push
// updates labels and toggle states and nothing else. An entity arriving or
// leaving while the menu is open therefore changes no row, which is what makes
// it impossible for one to move or vanish under the user's finger. Seeing a
// changed set of entities means reopening the menu.
class AreaEntityMenu extends WatchUi.Menu2 {
    private var _coordinator as Coordinator;
    private var _areaId as String;

    function initialize(coordinator as Coordinator, areaId as String, model as AreaEntityMenuModel) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _areaId = areaId;

        for (var index = 0; index < model.lights.size(); index++) {
            var row = model.lights[index];
            addItem(new WatchUi.ToggleMenuItem(
                resolveLabel(row.name, row.rowId), toLightSubLabel(row), row.rowId, row.isOn, null));
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            addItem(new WatchUi.MenuItem(
                resolveLabel(row.name, row.rowId), toSensorSubLabel(row), row.rowId, null));
        }

        if (model.lights.size() == 0 && model.sensors.size() == 0) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.NoEntitiesInArea) as String, null, :none, null));
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
        var model = AreaEntityMenuBuilder.build(haState, _areaId);
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

            if (item != null) {
                (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
                item.setSubLabel(toLightSubLabel(row));
            }
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            var item = findItem(row.rowId);

            if (item != null) {
                item.setSubLabel(toSensorSubLabel(row));
            }
        }
    }

    private function findItem(rowId as String) as WatchUi.MenuItem or Null {
        var index = findItemById(rowId);
        return index < 0 ? null : getItem(index);
    }

    static function resolveLabel(name as String or Null, rowId as String) as String {
        return name == null || (name as String).length() == 0 ? rowId : name as String;
    }

    static function toLightSubLabel(row as LightRowModel) as String or Null {
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

    static function toSensorSubLabel(row as SensorRowModel) as String {
        var displayValue = row.displayValue;

        if (!row.isAvailable || displayValue == null) {
            return WatchUi.loadResource(Rez.Strings.Unavailable) as String;
        }

        return displayValue as String;
    }
}
