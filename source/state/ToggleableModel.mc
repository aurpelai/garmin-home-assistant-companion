import Toybox.Lang;

// An actuator the watch switches on and off, named as one type so the
// optimistic-override machinery and the toggle rows can share a body.
typedef ToggleableModel as LightModel or FanModel;
