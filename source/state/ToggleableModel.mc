import Toybox.Lang;

// On either member, a group whose members have all vanished still arrives as a
// group, with an empty memberIds rather than null — a group is what memberIds
// being non-null means, never that it has members.
typedef ToggleableModel as LightModel or FanModel;
