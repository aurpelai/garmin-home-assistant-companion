import Toybox.Lang;

module EntityId {

    function getDomain(entityId as String) as String {
        var separatorIndex = entityId.find(".");
        return separatorIndex == null ? entityId : entityId.substring(0, separatorIndex) as String;
    }
}
