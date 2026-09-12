import Toybox.Lang;
import Toybox.WatchUi;

// A floor id and an area id can coincide (both are slugs of names), so the row
// itself is the item id and carries which set it belongs to.
class VisibilityToggleMenu extends WatchUi.Menu2 {

    function initialize(rows as Array<VisibilityRowModel>) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsFilter) as String });

        for (var index = 0; index < rows.size(); index++) {
            var row = rows[index];
            var subLabel = row instanceof FloorVisibilityRowModel ? resolveFloorSubLabel(row.areaCount) : null;
            addItem(new WatchUi.ToggleMenuItem(row.name, subLabel, row, row.isVisible, null));
        }
    }

    private function resolveFloorSubLabel(areaCount as Number) as String {
        if (areaCount == 1) {
            return WatchUi.loadResource(Rez.Strings.FloorAreaCountOne) as String;
        }

        return Lang.format(WatchUi.loadResource(Rez.Strings.FloorAreaCount) as String, [areaCount]);
    }
}
