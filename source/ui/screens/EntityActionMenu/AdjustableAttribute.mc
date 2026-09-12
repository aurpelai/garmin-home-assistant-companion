import Toybox.Lang;

class AdjustableAttribute {
    public var entityId as String;
    public var titleId as ResourceId;
    public var domain as String;
    public var service as String;
    public var offService as String or Null;
    public var field as String;
    public var unitId as ResourceId or Null;
    public var range as ValueRange or Null;
    public var current as Number or Null;
    public var isOn as Boolean or Null;

    function initialize(entityId as String, titleId as ResourceId, domain as String, service as String,
                        offService as String or Null, field as String, unitId as ResourceId or Null,
                        range as ValueRange or Null, current as Number or Null,
                        isOn as Boolean or Null) {
        self.entityId = entityId;
        self.titleId = titleId;
        self.domain = domain;
        self.service = service;
        self.offService = offService;
        self.field = field;
        self.unitId = unitId;
        self.range = range;
        self.current = current;
        self.isOn = isOn;
    }

    function isToggle() as Boolean {
        return range == null;
    }

    function selectService(value as Number) as String {
        var off = offService;
        return off != null && value == 0 ? off : service;
    }
}
