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

        for (var index = 0; index < model.rows.size(); index++) {
            addRow(model.rows[index]);
        }

        if (!hasEntityRows(model.rows)) {
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

        for (var index = 0; index < model.rows.size(); index++) {
            updateRow(model.rows[index]);
        }
    }

    static function resolveLabel(name as String or Null, id as String) as String {
        return name == null || (name as String).length() == 0 ? id : name as String;
    }

    protected function findItem(id as String) as WatchUi.MenuItem or Null {
        var index = findItemById(id);
        return index < 0 ? null : getItem(index);
    }

    private function addRow(row as MenuRowModel) as Void {
        if (row instanceof ToggleRowModel) {
            addItem(new WatchUi.ToggleMenuItem(
                resolveLabel(row.name, row.id), row.subLabel, row.id, row.isOn, null));
        } else if (row instanceof SensorRowModel) {
            addItem(new WatchUi.MenuItem(resolveLabel(row.name, row.id), row.subLabel, row.id, null));
        } else {
            addItem(new WatchUi.MenuItem(row.name, null, row.id, null));
        }
    }

    private function updateRow(row as MenuRowModel) as Void {
        var item = findItem(row.id);

        if (item == null) {
            return;
        }

        if (row instanceof ToggleRowModel) {
            (item as WatchUi.ToggleMenuItem).setEnabled(row.isOn);
            item.setSubLabel(row.subLabel);
        } else if (row instanceof SensorRowModel) {
            item.setSubLabel(row.subLabel);
        }
    }

    private function hasEntityRows(rows as Array<MenuRowModel>) as Boolean {
        for (var index = 0; index < rows.size(); index++) {
            if (!(rows[index] instanceof HeaderRowModel)) {
                return true;
            }
        }

        return false;
    }
}
