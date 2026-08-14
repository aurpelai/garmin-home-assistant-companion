import Toybox.Lang;

class ParsedStructure {
    public var zone as String or Null;
    public var areas as Dictionary<String, AreaModel>;
    public var floors as Array<FloorModel>;

    function initialize(zone as String or Null, areas as Dictionary<String, AreaModel>,
                        floors as Array<FloorModel>) {
        self.zone = zone;
        self.areas = areas;
        self.floors = floors;
    }
}
