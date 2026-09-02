import Toybox.Lang;

class ToggleableCount {
    public var on as Number;
    public var available as Number;
    public var unavailable as Number;

    function initialize(on as Number, available as Number, unavailable as Number) {
        self.on = on;
        self.available = available;
        self.unavailable = unavailable;
    }

    // Group wrappers are skipped (memberIds != null): the physical members carry
    // the state, and counting the wrapper too would double them.
    static function build(toggleables as Array<ToggleableModel>) as ToggleableCount {
        var on = 0;
        var available = 0;
        var unavailable = 0;

        for (var index = 0; index < toggleables.size(); index++) {
            var toggleable = toggleables[index];
            if (toggleable.memberIds != null) {
                continue;
            }

            if (toggleable.available) {
                available++;
                if (toggleable.isOn()) {
                    on++;
                }
            } else {
                unavailable++;
            }
        }

        return new ToggleableCount(on, available, unavailable);
    }
}
