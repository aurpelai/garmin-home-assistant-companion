import Toybox.Lang;

(:glance)
class MultiStatusRow {
    public var items as Array<StatusItem>;

    function initialize(items as Array<StatusItem>) {
        self.items = items;
    }
}
