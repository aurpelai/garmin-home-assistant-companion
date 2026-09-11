import Toybox.Lang;
import Toybox.WatchUi;

// A floor id and an area id can coincide (both are slugs of names), so the row
// itself is the item id and carries which set it belongs to.
class VisibilityToggleMenu extends WatchUi.Menu2 {

    function initialize(rows as Array<VisibilityToggleRowModel>) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsFilter) as String });

        for (var index = 0; index < rows.size(); index++) {
            var row = rows[index];
            var subLabel = WatchUi.loadResource(row.isFloor ? Rez.Strings.SettingsFloor : Rez.Strings.SettingsArea);
            addItem(new WatchUi.ToggleMenuItem(row.name, subLabel as String, row, row.isVisible, null));
        }
    }
}
