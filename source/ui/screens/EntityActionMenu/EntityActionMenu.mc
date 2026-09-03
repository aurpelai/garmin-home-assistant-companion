import Toybox.Lang;
import Toybox.WatchUi;

module EntityActionMenu {
    function build(attributes as Array<AdjustableAttribute>) as WatchUi.ActionMenu {
        var menu = new WatchUi.ActionMenu({ :theme => WatchUi.ACTION_MENU_THEME_DARK });

        for (var index = 0; index < attributes.size(); index++) {
            menu.addItem(new WatchUi.ActionMenuItem(
                { :label => WatchUi.loadResource(attributes[index].titleId) as String }, index));
        }

        return menu;
    }
}
