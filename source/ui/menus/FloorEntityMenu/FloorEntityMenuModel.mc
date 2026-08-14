import Toybox.Lang;

// A floor carries one row per domain present on it, so a floor with no
// commandable lights has an empty lights array rather than a disabled row.
class FloorEntityMenuModel {
    public var title as String;
    public var lights as Array<LightRowModel>;

    function initialize(title as String, lights as Array<LightRowModel>) {
        self.title = title;
        self.lights = lights;
    }
}
