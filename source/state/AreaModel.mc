import Toybox.Lang;

// No entity lists: an area's membership is grouped from each entity's own area
// id by the target that carries the entities, so it cannot be known here.
class AreaModel {
    public var name as String or Null;

    function initialize(name as String or Null) {
        self.name = name;
    }
}
