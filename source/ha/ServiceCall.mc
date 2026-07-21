import Toybox.Lang;

// Pure builders for HA light service calls. Kept separate from HaClient so the
// payload logic is unit-testable without a network stack.
//
// HA service endpoint: POST /api/services/light/{turn_on|turn_off|toggle}
// Body targets either a single entity or a whole area.
module ServiceCall {

    enum {
        SERVICE_TURN_ON,
        SERVICE_TURN_OFF,
        SERVICE_TOGGLE
    }

    function servicePath(service as Number) as String {
        var name;
        switch (service) {
            case SERVICE_TURN_ON:  name = "turn_on";  break;
            case SERVICE_TURN_OFF: name = "turn_off"; break;
            default:               name = "toggle";   break;
        }
        return "/api/services/light/" + name;
    }

    function entityBody(entityId as String) as Dictionary {
        return { "entity_id" => entityId };
    }
}
