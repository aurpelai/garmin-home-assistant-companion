import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure service-call payload/path builders.

(:test)
function servicePathsAreCorrect(logger as Test.Logger) as Boolean {
    Test.assertEqual(ServiceCall.servicePath(ServiceCall.SERVICE_TURN_ON), "/api/services/light/turn_on");
    Test.assertEqual(ServiceCall.servicePath(ServiceCall.SERVICE_TURN_OFF), "/api/services/light/turn_off");
    Test.assertEqual(ServiceCall.servicePath(ServiceCall.SERVICE_TOGGLE), "/api/services/light/toggle");
    return true;
}

(:test)
function entityBodyTargetsSingleEntity(logger as Test.Logger) as Boolean {
    var body = ServiceCall.entityBody("light.kitchen");
    Test.assertEqual(body.get("entity_id") as String, "light.kitchen");
    return true;
}

(:test)
function areaBodyTargetsArea(logger as Test.Logger) as Boolean {
    var body = ServiceCall.areaBody("kitchen");
    Test.assertEqual(body.get("area_id") as String, "kitchen");
    return true;
}
