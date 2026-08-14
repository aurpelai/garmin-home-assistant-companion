import Toybox.Lang;

class FloorModel {
    public var id as String;
    public var name as String or Null;
    public var order as Number;
    public var areas as Array<String>;

    function initialize(id as String, name as String or Null, order as Number, areas as Array<String>) {
        self.id = id;
        self.name = name;
        self.order = order;
        self.areas = areas;
    }
}
