import Toybox.Lang;

class AdjustableAttribute {
    public var entityId as String;
    public var titleId as ResourceId;
    public var domain as String;
    public var service as String;
    public var field as String;
    public var unitId as ResourceId or Null;
    public var range as LevelRange or Null;
    public var current as Number or Null;
    public var currentOn as Boolean or Null;

    function initialize(entityId as String, titleId as ResourceId, domain as String, service as String,
                        field as String, unitId as ResourceId or Null, range as LevelRange or Null,
                        current as Number or Null, currentOn as Boolean or Null) {
        self.entityId = entityId;
        self.titleId = titleId;
        self.domain = domain;
        self.service = service;
        self.field = field;
        self.unitId = unitId;
        self.range = range;
        self.current = current;
        self.currentOn = currentOn;
    }

    function isToggle() as Boolean {
        return range == null;
    }
}
