import Toybox.Lang;

class LabelPickerRowModel {
    public var id as String;
    public var name as String;
    public var isIncluded as Boolean;

    function initialize(id as String, name as String, isIncluded as Boolean) {
        self.id = id;
        self.name = name;
        self.isIncluded = isIncluded;
    }
}
