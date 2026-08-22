import Toybox.Lang;

// Server truth for one light, plus the value a tap assumed until its reply
// settles. `state` is never overwritten: `assumed` sits over it, so reverting is
// deletion rather than restoration. A refresh carries a live assumption onto the
// replacing model, since the server has not seen the tap yet.
class LightModel {
    public var id as String;
    public var state as Boolean;
    public var name as String;
    public var available as Boolean;
    public var areaId as String or Null;
    // Groups only; the member count is memberIds.size().
    public var memberIds as Array<String> or Null;
    public var assumed as Boolean or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null) {
        self.id = id;
        self.state = state;
        self.name = name;
        self.available = available;
        self.areaId = areaId;
        self.memberIds = memberIds;
        assumed = null;
    }

    function isOn() as Boolean {
        return assumed != null ? assumed : state;
    }

    function isPending() as Boolean {
        return assumed != null;
    }
}
