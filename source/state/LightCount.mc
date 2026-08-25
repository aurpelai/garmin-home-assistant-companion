import Toybox.Lang;

class LightCount {
    public var on as Number;
    public var available as Number;
    public var unavailable as Number;

    function initialize(on as Number, available as Number, unavailable as Number) {
        self.on = on;
        self.available = available;
        self.unavailable = unavailable;
    }
}
