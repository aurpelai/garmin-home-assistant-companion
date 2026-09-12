import Toybox.Lang;

class FloorVisibilityRowModel extends VisibilityRowModel {
    public var areaCount as Number;

    function initialize(id as String, name as String, areaCount as Number, isVisible as Boolean) {
        VisibilityRowModel.initialize(id, name, isVisible);
        self.areaCount = areaCount;
    }
}
