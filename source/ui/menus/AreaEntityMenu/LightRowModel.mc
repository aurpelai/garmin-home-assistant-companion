import Toybox.Lang;

// One light row's facts. The sublabel that picks between unavailable, a group
// count and nothing is composed by the view, so no display text is stored here.
class LightRowModel {
    public var rowId as String;
    // Coincides with rowId on an entity row and diverges on a floor row.
    public var serviceTarget as String;
    public var name as String or Null;
    public var isOn as Boolean;
    public var isAvailable as Boolean;
    public var memberCount as Number or Null;
    public var isPending as Boolean;

    function initialize(rowId as String, serviceTarget as String, name as String or Null,
                        isOn as Boolean, isAvailable as Boolean, memberCount as Number or Null,
                        isPending as Boolean) {
        self.rowId = rowId;
        self.serviceTarget = serviceTarget;
        self.name = name;
        self.isOn = isOn;
        self.isAvailable = isAvailable;
        self.memberCount = memberCount;
        self.isPending = isPending;
    }
}
