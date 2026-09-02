import Toybox.Lang;

// A floor carries one row per domain present on it, so a floor with no lights
// has an empty lights array rather than a disabled row.
class FloorEntityMenuModel {
    // UNVERIFIED: a hyphen cannot occur in a Home Assistant object id, so this
    // sentinel can never collide with a real one.
    static const LIGHTS_ROW_ID = "all-lights";

    public var title as String;
    public var lights as Array<ToggleRowModel>;

    function initialize(title as String, lights as Array<ToggleRowModel>) {
        self.title = title;
        self.lights = lights;
    }
}
