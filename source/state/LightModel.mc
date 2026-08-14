import Toybox.Lang;

// Server truth for one light. Overrides resolve in HaState, never here.
class LightModel {
    public var state as Boolean;
    public var name as String or Null;
    public var available as Boolean;
    // Groups only; the member count is memberIds.size().
    public var memberIds as Array<String> or Null;

    function initialize(state as Boolean, name as String or Null, available as Boolean,
                        memberIds as Array<String> or Null) {
        self.state = state;
        self.name = name;
        self.available = available;
        self.memberIds = memberIds;
    }
}
