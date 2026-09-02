import Toybox.Lang;

class AreaEntityMenuModel {
    public var title as String;
    public var toggles as Array<ToggleRowModel>;
    public var sensors as Array<SensorRowModel>;

    function initialize(title as String, toggles as Array<ToggleRowModel>,
                        sensors as Array<SensorRowModel>) {
        self.title = title;
        self.toggles = toggles;
        self.sensors = sensors;
    }
}
