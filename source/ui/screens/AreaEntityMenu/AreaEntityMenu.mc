import Toybox.Lang;
import Toybox.WatchUi;

// The item set is built once here and frozen for the life of the menu: a
// rebuild updates labels and toggle states and nothing else, never the set of
// rows. An entity arriving or leaving while the menu is open therefore moves no
// row and removes none under the user's finger; seeing the change means
// reopening the menu.
class AreaEntityMenu extends WatchUi.Menu2 {
    private var _coordinator as Coordinator;
    private var _areaId as String;
    private var _subLabelProvider as SubLabelProvider;

    function initialize(coordinator as Coordinator, areaId as String, model as AreaEntityMenuModel,
                        subLabelProvider as SubLabelProvider) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _areaId = areaId;
        _subLabelProvider = subLabelProvider;

        for (var index = 0; index < model.toggles.size(); index++) {
            var row = model.toggles[index];
            addItem(new WatchUi.ToggleMenuItem(
                resolveLabel(row.name, row.rowId), row.subLabel, row.rowId, row.isOn, null));
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            addItem(new WatchUi.MenuItem(
                resolveLabel(row.name, row.rowId), row.subLabel, row.rowId, null));
        }

        if (model.toggles.size() == 0 && model.sensors.size() == 0) {
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

    function hasPerished(haState as HaState) as Boolean {
        return haState.getArea(_areaId) == null;
    }

    function rebuild(haState as HaState) as Void {
        var model = AreaEntityMenuBuilder.build(haState, _areaId, _subLabelProvider);
        if (model != null) {
            setModel(model);
        }
    }

    function setModel(model as AreaEntityMenuModel) as Void {
        setTitle(model.title);

        for (var index = 0; index < model.toggles.size(); index++) {
            var row = model.toggles[index];
            var item = findItem(row.rowId);

            if (item != null) {
                (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
                item.setSubLabel(row.subLabel);
            }
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            var item = findItem(row.rowId);

            if (item != null) {
                item.setSubLabel(row.subLabel);
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
}
