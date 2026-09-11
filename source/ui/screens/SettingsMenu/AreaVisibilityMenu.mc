import Toybox.Lang;
import Toybox.WatchUi;

class AreaVisibilityMenu extends WatchUi.Menu2 {
    static const OTHER_ROW_ID = "other-areas";

    function initialize(rows as Array<AreaVisibilityRowModel>) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsAreas) as String });

        for (var index = 0; index < rows.size(); index++) {
            var row = rows[index];
            var subLabelId = row.subLabelId;
            var subLabel = subLabelId == null ? null : WatchUi.loadResource(subLabelId) as String;
            addItem(new WatchUi.MenuItem(row.name, subLabel, row.id, null));
        }
    }
}
