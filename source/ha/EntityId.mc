import Toybox.Lang;

module EntityId {

    function getDomain(entityId as String) as String {
        var dot = entityId.find(".");
        return dot == null ? entityId : entityId.substring(0, dot) as String;
    }
}
