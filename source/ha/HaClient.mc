import Toybox.Communications;
import Toybox.Lang;

// Everything rides one webhook template render because a plain GET /api/states
// returns every entity in the instance and blows past Connect IQ's HTTP
// response-size limit.
class HaClient {
    // The device can't introspect its real model/OS, so every install registers
    // under these same constants.
    private const DEVICE_ID = "companion_for_home_assistant";
    private const APP_ID = "companion_for_home_assistant";
    private const APP_NAME = "Companion For Home Assistant";
    private const APP_VERSION = "0.3.0";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    // Piped through `| tojson`: the render_template webhook returns the rendered
    // value as a string, so without it the payload is a Python repr (single
    // quotes, True/False, enum units) that no JSON reader accepts. tojson makes
    // it well-formed JSON, which JsonParser then decodes on-device.
    //
    // Deliberately backslash-free: we filter entities with `.startswith(...)`
    // instead of a regex like select('match','^light\.'). A backslash in this
    // string would be sent unescaped by the Connect IQ JSON serializer, producing
    // an invalid JSON escape and a 400 "Invalid JSON specified" from HA.
    private const HOME_STATE_TEMPLATE =
        "{% set ns = namespace(lights={}, sensors={}, areaLights={}, areaSensors={}, " +
            "areasOut={}, floorsOut={}) %}" +
        "{% for a in areas() %}" +

        // `| list` is load-bearing: reject() yields a generator that the second
        // (per-device_class) walk below would find already exhausted. Needs HA 2023.4.
        "{% set visible = area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% set ns.areaLights = [] %}" +
        "{% set ns.areaSensors = [] %}" +

        // Skip any area-assigned entity with no state object: `states[e].name`
        // on it renders Undefined, and the closing `| tojson` would then fail the
        // whole render rather than omit one row. Not known to occur via any
        // user-reachable path (disabled entities are already absent here), but the
        // blast radius is the entire payload, so the id is dropped defensively.
        "{% for e in visible %}" +
        "{% if e.startswith('light.') and states[e] is not none %}" +
        "{% set isGroup = state_attr(e, 'entity_id') is not none %}" +
        "{% set visibleMembers = expand(e) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| list | count if isGroup else 0 %}" +
        "{% if not isGroup or visibleMembers > 0 %}" +
        "{% set ns.areaLights = ns.areaLights + [e] %}" +
        "{% set light = dict(state=is_state(e, 'on'), name=states[e].name, " +
            "available=not is_state(e, 'unavailable')) %}" +
        "{% if isGroup %}" +
        "{% set light = dict(light, memberCount=visibleMembers) %}" +
        "{% endif %}" +
        "{% set ns.lights = dict(ns.lights, **{e: light}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +

        // `states(e, true, true)` keeps HA's own display precision and unit as a
        // string, so the watch never reparses or rounds and can't disagree with
        // the user's dashboard. Needs HA 2023.3.
        "{% for device_class in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% for e in visible %}" +
        "{% if e.startswith('sensor.') and state_attr(e, 'device_class') == device_class %}" +
        "{% set ns.areaSensors = ns.areaSensors + [e] %}" +
        "{% set ns.sensors = dict(ns.sensors, **{e: dict(" +
            "state=states(e) | float(0), display_state=states(e, true, true), " +
            "unit=state_attr(e, 'unit_of_measurement'), device_class=device_class, " +
            "name=entity_name(e), " +
            "available=not is_state(e, 'unavailable') and not is_state(e, 'unknown'))}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +

        "{% if ns.areaLights or ns.areaSensors %}" +
        "{% set ns.areasOut = dict(ns.areasOut, **{a: dict(" +
            "name=area_name(a), lights=ns.areaLights, sensors=ns.areaSensors)}) %}" +
        "{% endif %}" +
        "{% endfor %}" +

        // On `ns` because a plain `{% set %}` inside a Jinja for-loop is scoped
        // to the iteration and wouldn't escape.
        "{% for f in floors() %}" +
        "{% set ns.floorsOut = dict(ns.floorsOut, **{f: dict(" +
            "name=floor_name(f), order=loop.index0, areas=floor_areas(f) | list)}) %}" +
        "{% endfor %}" +

        "{% set zone = state_attr('zone.home', 'friendly_name') %}" +

        "{{ dict(zone=zone, lights=ns.lights, sensors=ns.sensors, " +
            "areas=ns.areasOut, floors=ns.floorsOut) | tojson }}";

    function initialize() {}

    function fetchHomeState(callback as Method) as Void {
        new RecoveryHandler(self, method(:fetch), callback).attempt();
    }

    function register(callback as Method) as Void {
        var body = {
            "device_id" => DEVICE_ID,
            "app_id" => APP_ID,
            "app_name" => APP_NAME,
            "app_version" => APP_VERSION,
            "device_name" => DEVICE_NAME,
            "manufacturer" => MANUFACTURER,
            "model" => MODEL,
            "os_name" => OS_NAME,
            "os_version" => OS_VERSION,
            "supports_encryption" => false,
            "app_data" => {}
        };
        post("/api/mobile_app/registrations", body,
             new ResponseHandler(new RegisterCacheHandler(callback).method(:onRegistered), :onRegister));
    }

    function toggleLight(entityId as String, callback as Method) as Void {
        new RecoveryHandler(self, new ServiceCallHandler(self, entityId).method(:callService), callback).attempt();
    }

    function toggleFloorLights(floorId as String, service as String, callback as Method) as Void {
        new RecoveryHandler(self,
            new FloorServiceCallHandler(self, floorId, service).method(:callFloorService), callback).attempt();
    }

    function fetch(callback as Method) as Void {
        var webhookId = Settings.getWebhookId();

        if (webhookId == null) {
            callback.invoke(null, 404);
            return;
        }

        var body = {
            "type" => "render_template",
            "data" => {
                "home" => {
                    "template" => HOME_STATE_TEMPLATE
                }
            }
        };
        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, :onTemplate));
    }

    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + Settings.getToken(),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            Settings.getBaseUrl() + path,
            body as Dictionary<Object, Object>,
            options,
            handler.method(:onResponse)
        );
    }
}
