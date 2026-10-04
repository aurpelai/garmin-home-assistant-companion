import Toybox.Lang;

class EntityMenuModel {
    public var title as String;
    public var rows as Array<MenuRowModel>;

    function initialize(title as String, rows as Array<MenuRowModel>) {
        self.title = title;
        self.rows = rows;
    }
}
