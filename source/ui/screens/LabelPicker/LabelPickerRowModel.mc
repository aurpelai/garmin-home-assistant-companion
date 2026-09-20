import Toybox.Lang;

class LabelPickerRowModel {
    public var id as String;
    public var name as String;
    public var isWatched as Boolean;

    function initialize(id as String, name as String, isWatched as Boolean) {
        self.id = id;
        self.name = name;
        self.isWatched = isWatched;
    }
}
