import Toybox.Lang;

class LightRowModel {
    public var rowId as String;
    public var name as String or Null;
    public var isOn as Boolean;
    public var isAvailable as Boolean;
    public var memberCount as Number or Null;

    function initialize(rowId as String, name as String or Null, isOn as Boolean,
                        isAvailable as Boolean, memberCount as Number or Null) {
        self.rowId = rowId;
        self.name = name;
        self.isOn = isOn;
        self.isAvailable = isAvailable;
        self.memberCount = memberCount;
    }
}
