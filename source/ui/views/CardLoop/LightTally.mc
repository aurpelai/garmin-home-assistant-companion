import Toybox.Lang;

// Groups are excluded so a group and its members are not both counted.
class LightTally {
    public var on as Number;
    public var available as Number;
    public var unavailable as Number;

    function initialize() {
        on = 0;
        available = 0;
        unavailable = 0;
    }

    function addAll(haState as HaState, lights as Array<LightModel>) as Void {
        for (var index = 0; index < lights.size(); index++) {
            var light = lights[index];

            if (light.memberIds != null) {
                continue;
            }

            if (!light.available) {
                unavailable++;
            } else {
                available++;

                if (haState.isOn(light.id)) {
                    on++;
                }
            }
        }
    }
}
