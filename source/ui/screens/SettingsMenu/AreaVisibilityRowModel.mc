import Toybox.Lang;

class AreaVisibilityRowModel {
    public var id as String;
    public var name as String;
    public var subLabelId as ResourceId or Null;

    function initialize(id as String, name as String, subLabelId as ResourceId or Null) {
        self.id = id;
        self.name = name;
        self.subLabelId = subLabelId;
    }
}
