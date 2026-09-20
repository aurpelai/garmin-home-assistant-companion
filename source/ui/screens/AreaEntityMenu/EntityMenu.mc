import Toybox.Lang;
import Toybox.WatchUi;

// The item set is built once here and frozen for the life of the menu: a
// rebuild updates labels and toggle states and nothing else, never the set of
// rows. An entity arriving or leaving while the menu is open therefore moves no
// row and removes none under the user's finger; seeing the change means
// reopening the menu.
class EntityMenu extends WatchUi.Menu2 {
    protected var _coordinator as Coordinator;
    protected var _subLabelProvider as SubLabelProvider;

    function initialize(coordinator as Coordinator, model as EntityMenuModel, emptyLabel as String,
                        subLabelProvider as SubLabelProvider) {
        Menu2.initialize({ :title => model.title });
        _coordinator = coordinator;
        _subLabelProvider = subLabelProvider;

        for (var index = 0; index < model.toggles.size(); index++) {
            var row = model.toggles[index];
            addItem(new WatchUi.ToggleMenuItem(
                resolveLabel(row.name, row.id), row.subLabel, row.id, row.isOn, null));
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            addItem(new WatchUi.MenuItem(
                resolveLabel(row.name, row.id), row.subLabel, row.id, null));
        }

        if (model.toggles.size() == 0 && model.sensors.size() == 0) {
            addItem(new WatchUi.MenuItem(emptyLabel, null, :none, null));
        }

        setModel(model);
    }

    function onShow() as Void {
        _coordinator.onViewShown(self);
    }

    function onHide() as Void {
        _coordinator.onViewHidden(self);
    }

    function setModel(model as EntityMenuModel) as Void {
        setTitle(model.title);

        for (var index = 0; index < model.toggles.size(); index++) {
            var row = model.toggles[index];
            var item = findItem(row.id);

            if (item != null) {
                (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
                item.setSubLabel(row.subLabel);
            }
        }

        for (var index = 0; index < model.sensors.size(); index++) {
            var row = model.sensors[index];
            var item = findItem(row.id);

            if (item != null) {
                item.setSubLabel(row.subLabel);
            }
        }
    }

    protected function findItem(id as String) as WatchUi.MenuItem or Null {
        var index = findItemById(id);
        return index < 0 ? null : getItem(index);
    }

    static function resolveLabel(name as String or Null, id as String) as String {
        return name == null || (name as String).length() == 0 ? id : name as String;
    }
}
