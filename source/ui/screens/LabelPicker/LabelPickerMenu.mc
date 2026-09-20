import Toybox.Lang;
import Toybox.WatchUi;

class LabelPickerMenu extends WatchUi.Menu2 {

    function initialize(rows as Array<LabelPickerRowModel>) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsWatchLabels) as String });

        for (var index = 0; index < rows.size(); index++) {
            var row = rows[index];
            addItem(new WatchUi.ToggleMenuItem(row.name, null, row.id, row.isWatched, null));
        }
    }
}
