import Toybox.Lang;

// A floor carries one row per domain present on it, so a floor with no lights
// has an empty lights array rather than a disabled row.
class FloorEntityMenuModel {
    // Home Assistant validates an object id against [a-z0-9_], so a hyphen can
    // never occur in a real entity id and this sentinel collides with none
    // (verified from the Home Assistant core source on 2026-09-12).
    static const LIGHTS_ROW_ID = "all-lights";

    public var title as String;
    public var lights as Array<ToggleRowModel>;

    function initialize(title as String, lights as Array<ToggleRowModel>) {
        self.title = title;
        self.lights = lights;
    }
}
