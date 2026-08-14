import Toybox.Lang;

// A floor carries one row per domain present on it, so a floor with no lights
// has an empty lights array rather than a disabled row.
class FloorEntityMenuModel {
    // The id of the whole-lights row, deliberately not shaped like an entity id:
    // this row's identity and its service target diverge, the target being the
    // floor. A hyphen cannot occur in a Home Assistant object id, so it can never
    // be mistaken for one or collide with one.
    static const LIGHTS_ROW_ID = "all-lights";

    public var title as String;
    public var lights as Array<LightRowModel>;

    function initialize(title as String, lights as Array<LightRowModel>) {
        self.title = title;
        self.lights = lights;
    }
}
