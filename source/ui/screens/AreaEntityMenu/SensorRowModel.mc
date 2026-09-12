import Toybox.Lang;

class SensorRowModel {
    public var id as String;
    public var name as String or Null;
    public var subLabel as String;

    function initialize(id as String, name as String or Null, subLabel as String) {
        self.id = id;
        self.name = name;
        self.subLabel = subLabel;
    }
}
