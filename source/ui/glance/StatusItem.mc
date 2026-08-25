import Toybox.Lang;

(:glance)
class StatusItem {
    public var icon as ResourceId;
    public var tint as Number;
    public var text as String;
    public var x as Number;

    function initialize(icon as ResourceId, tint as Number, text as String, x as Number) {
        self.icon = icon;
        self.tint = tint;
        self.text = text;
        self.x = x;
    }
}
