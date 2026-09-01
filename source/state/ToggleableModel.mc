import Toybox.Lang;

// An actuator the watch switches on and off, named as one type so the
// optimistic-override machinery and the toggle rows can share a body.
//
// On either member, a group whose members have all vanished still arrives as a
// group, with an empty memberIds rather than null — a group is what memberIds
// being non-null means, never that it has members.
typedef ToggleableModel as LightModel or FanModel;
