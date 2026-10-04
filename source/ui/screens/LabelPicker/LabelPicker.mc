import Toybox.Lang;
import Toybox.WatchUi;

class LabelPicker extends WatchUi.Menu2 {

    function initialize(rows as Array<LabelPickerRowModel>) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsIncludeLabels) as String });

        for (var index = 0; index < rows.size(); index++) {
            var row = rows[index];
            addItem(new WatchUi.ToggleMenuItem(row.name, null, row.id, row.isIncluded, null));
        }
    }
}
