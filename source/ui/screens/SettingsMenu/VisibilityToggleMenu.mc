import Toybox.Lang;
import Toybox.WatchUi;

class VisibilityToggleMenu extends WatchUi.Menu2 {

    function initialize(title as String, rows as Array<VisibilityToggleRowModel>) {
        Menu2.initialize({ :title => title });

        for (var index = 0; index < rows.size(); index++) {
            var row = rows[index];
            addItem(new WatchUi.ToggleMenuItem(row.name, null, row.id, row.isVisible, null));
        }
    }
}
