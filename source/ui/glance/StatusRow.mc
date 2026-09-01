import Toybox.Lang;

(:glance)
class StatusRow {
    public var items as Array<StatusItem>;

    function initialize(items as Array<StatusItem>) {
        self.items = items;
    }
}
