import Toybox.Lang;

// A group whose members have all vanished still arrives as a group, with an
// empty memberIds rather than null — a group is what memberIds being non-null
// means, never that it has members.
class ToggleableModel {
    public var id as String;
    public var domain as String;
    public var state as Boolean;
    public var name as String;
    public var available as Boolean;
    public var areaId as String or Null;
    public var memberIds as Array<String> or Null;
    public var assumedState as Boolean or Null;

    function initialize(id as String, state as Boolean, name as String, available as Boolean,
                        areaId as String or Null, memberIds as Array<String> or Null) {
        self.id = id;
        self.state = state;
        self.name = name;
        self.available = available;
        self.areaId = areaId;
        self.memberIds = memberIds;
        domain = Entity.resolveDomain(id);
        assumedState = null;
    }

    function isOn() as Boolean {
        return assumedState != null ? assumedState : state;
    }

    function isPending() as Boolean {
        return assumedState != null;
    }
}
