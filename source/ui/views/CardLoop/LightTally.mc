import Toybox.Lang;

// A scope's physical lights counted the three ways a card's dot row draws them.
// Groups are excluded so a group and its members are not both counted, and `on`
// is counted among available lights only, an unreachable light having no state
// worth claiming.
//
// Presentation rather than a domain fact, which is why it sits beside the cards
// rather than in HaState: change the card to two dot styles and this changes
// while nothing in the house moves. It reads state through the argument it is
// handed, exactly as the builders do, and holds none.
class LightTally {
    public var on as Number;
    public var available as Number;
    public var unavailable as Number;

    function initialize() {
        on = 0;
        available = 0;
        unavailable = 0;
    }

    function add(haState as HaState, entityIds as Array<String>) as Void {
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var light = haState.getLight(entityId);

            if (light == null || light.memberIds != null) {
                continue;
            }

            if (!light.available) {
                unavailable++;
            } else {
                available++;

                if (haState.isOn(entityId)) {
                    on++;
                }
            }
        }
    }
}
