import Toybox.Lang;

// Groups are excluded so a group and its members are not both counted, and an
// unavailable light is counted apart from the on/off split rather than claimed
// to be off.
//
// Presentation rather than a domain fact, which is why it sits beside the cards
// rather than in HaState: change the card to two dot styles and this changes
// while nothing in the house moves.
class LightTally {
    public var on as Number;
    public var available as Number;
    public var unavailable as Number;

    function initialize() {
        on = 0;
        available = 0;
        unavailable = 0;
    }

    // Adds to the running counts rather than replacing them, so a floor sums its
    // areas by calling this once per area. One instance therefore counts one
    // scope: reusing it across two would report their total as one card's.
    function addAll(haState as HaState, entityIds as Array<String>) as Void {
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
