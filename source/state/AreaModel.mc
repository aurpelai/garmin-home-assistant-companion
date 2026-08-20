import Toybox.Lang;

// No entity lists: an area's membership is grouped from each entity's own area
// id by the target that carries the entities, so it cannot be known here.
class AreaModel {
    public var id as String;
    public var name as String;

    function initialize(id as String, name as String) {
        self.id = id;
        self.name = name;
    }
}
